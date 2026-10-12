#include "download_platform.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shlobj.h>

#include <string>

namespace {
std::string ToUtf8(const std::wstring& value) {
  const int length = WideCharToMultiByte(CP_UTF8, 0, value.data(),
      static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
  std::string result(static_cast<size_t>(length), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
      result.data(), length, nullptr, nullptr);
  return result;
}

std::wstring ToWide(const std::string& value) {
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      value.data(), static_cast<int>(value.size()), nullptr, 0);
  std::wstring result(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), result.data(), length);
  return result;
}

bool KnownFolder(REFKNOWNFOLDERID id, std::string* value) {
  PWSTR path = nullptr;
  const HRESULT status = SHGetKnownFolderPath(id, KF_FLAG_CREATE, nullptr, &path);
  if (FAILED(status)) return false;
  *value = ToUtf8(path);
  CoTaskMemFree(path);
  return !value->empty();
}
}

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateDownloadPlatformChannel(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "universal_downloader/windows",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() == "directories") {
      std::string local_app_data;
      std::string downloads;
      if (!KnownFolder(FOLDERID_LocalAppData, &local_app_data) ||
          !KnownFolder(FOLDERID_Downloads, &downloads)) {
        result->Error("directories", "Windows application directories are unavailable.");
        return;
      }
      result->Success(flutter::EncodableValue(flutter::EncodableMap{
          {flutter::EncodableValue("localAppData"), flutter::EncodableValue(local_app_data)},
          {flutter::EncodableValue("downloads"), flutter::EncodableValue(downloads)},
      }));
      return;
    }
    if (call.method_name() == "revealFile") {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      const std::string* path = nullptr;
      if (args) {
        const auto entry = args->find(flutter::EncodableValue("path"));
        if (entry != args->end()) path = std::get_if<std::string>(&entry->second);
      }
      if (!path || path->empty() || path->find('\0') != std::string::npos) {
        result->Error("arguments", "A file path is required.");
        return;
      }
      const auto wide_path = ToWide(*path);
      PIDLIST_ABSOLUTE item = nullptr;
      HRESULT status = SHParseDisplayName(wide_path.c_str(), nullptr, &item, 0, nullptr);
      if (SUCCEEDED(status)) {
        status = SHOpenFolderAndSelectItems(item, 0, nullptr, 0);
        CoTaskMemFree(item);
      }
      if (FAILED(status)) {
        result->Error("reveal", "Could not open the download location.");
      } else {
        result->Success();
      }
      return;
    }
    result->NotImplemented();
  });
  return channel;
}
