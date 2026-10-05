import '../core/process/command_runner.dart';
import '../core/services/log_service.dart';
import '../core/tools/media_tools.dart';
import '../downloads/download_repository.dart';

class ProviderDependencies {
  const ProviderDependencies({
    required this.runner,
    required this.repository,
    required this.log,
    required this.tools,
  });

  final CommandRunner runner;
  final DownloadRepository repository;
  final LogService log;
  final MediaTools tools;
}
