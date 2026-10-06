enum ToolPlatform {
  linuxX64('linux-x64', 'Linux x64', ''),
  windowsX64('windows-x64', 'Windows x64', '.exe');

  const ToolPlatform(this.id, this.label, this.executableSuffix);

  final String id;
  final String label;
  final String executableSuffix;

  String executableName(String name) => '$name$executableSuffix';
}
