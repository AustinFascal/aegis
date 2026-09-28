import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/server_profile.dart';
import '../../providers/server_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/ssh_service.dart';
import '../widgets/two_factor_auth_dialog.dart';
import 'terminal_screen.dart';

enum SftpConnectionState { connecting, connected, error, disconnected }

enum SftpSortBy { name, size, date, type }

class SftpScreen extends StatefulWidget {
  final ServerProfile server;
  final String initialPath;
  @visibleForTesting
  final SftpConnectionState? initialConnectionStateForTesting;
  @visibleForTesting
  final List<SftpName>? initialItemsForTesting;

  const SftpScreen({
    super.key,
    required this.server,
    this.initialPath = '/',
    this.initialConnectionStateForTesting,
    this.initialItemsForTesting,
  });

  @override
  State<SftpScreen> createState() => _SftpScreenState();
}

class _SftpScreenState extends State<SftpScreen> {
  final SshService _sshService = SshService();
  SSHClient? _client;
  SftpClient? _sftp;

  SftpConnectionState _connectionState = SftpConnectionState.connecting;
  String? _errorMessage;

  late String _currentPath;
  List<SftpName> _items = [];
  bool _isLoadingDirectory = false;
  String? _directoryError;

  bool _showHiddenFiles = false;
  String _searchQuery = '';
  SftpSortBy _sortBy = SftpSortBy.name;
  bool _sortAscending = true;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    if (widget.initialConnectionStateForTesting != null) {
      _connectionState = widget.initialConnectionStateForTesting!;
      _items = widget.initialItemsForTesting ?? [];
    } else {
      _initSftpConnection();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _closeConnection();
    super.dispose();
  }

  void _closeConnection() {
    try {
      _sftp?.close();
      _client?.close();
    } catch (_) {}
    _sftp = null;
    _client = null;
  }

  Future<void> _initSftpConnection() async {
    if (!mounted) return;

    setState(() {
      _connectionState = SftpConnectionState.connecting;
      _errorMessage = null;
    });

    _closeConnection();

    final serverProvider = context.read<ServerProvider>();

    try {
      final credential = await serverProvider.getCredentialForServer(widget.server);
      final totpSecret = await serverProvider.get2FASecretForServer(widget.server);

      if (credential == null || credential.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _connectionState = SftpConnectionState.error;
          _errorMessage = 'Kredensial SSH (Private Key atau Password) belum dikonfigurasi untuk "${widget.server.name}". Masukkan kredensial di menu Konfigurasi Server.';
        });
        return;
      }

      final client = await _sshService.connectClient(
        profile: widget.server,
        credential: credential,
        totpSecret: totpSecret,
        onPrompt2FA: (prompt) async {
          if (!mounted) return null;
          return TwoFactorAuthDialog.show(
            context,
            username: widget.server.username,
            serverName: widget.server.name,
            promptText: prompt,
          );
        },
      );

      final sftp = await client.sftp();

      if (!mounted) {
        sftp.close();
        client.close();
        return;
      }

      _client = client;
      _sftp = sftp;

      setState(() {
        _connectionState = SftpConnectionState.connected;
      });

      await _loadDirectory(_currentPath);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectionState = SftpConnectionState.error;
        _errorMessage = 'Gagal menghubungkan SFTP: $e';
      });
    }
  }

  Future<void> _loadDirectory(String path) async {
    if (_sftp == null || !mounted) return;

    setState(() {
      _isLoadingDirectory = true;
      _directoryError = null;
    });

    try {
      final rawItems = await _sftp!.listdir(path);
      // Filter out '.' and '..' entries from listdir
      final filtered = rawItems.where((i) => i.filename != '.' && i.filename != '..').toList();

      if (!mounted) return;
      setState(() {
        _currentPath = path;
        _items = filtered;
        _isLoadingDirectory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _directoryError = 'Gagal membaca direktori "$path": $e';
        _isLoadingDirectory = false;
      });
    }
  }

  String _getParentPath(String path) {
    if (path == '/' || path.isEmpty) return '/';
    final trimmed = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    final lastSlash = trimmed.lastIndexOf('/');
    if (lastSlash <= 0) return '/';
    return trimmed.substring(0, lastSlash);
  }

  String _joinPath(String parent, String child) {
    if (parent == '/') return '/$child';
    if (parent.endsWith('/')) return '$parent$child';
    return '$parent/$child';
  }

  List<SftpName> get _filteredAndSortedItems {
    var list = _items.toList();

    // Filter hidden files
    if (!_showHiddenFiles) {
      list = list.where((item) => !item.filename.startsWith('.')).toList();
    }

    // Filter search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((item) => item.filename.toLowerCase().contains(q)).toList();
    }

    // Sort folders first, then files
    list.sort((a, b) {
      final aIsDir = a.attr.isDirectory;
      final bIsDir = b.attr.isDirectory;

      if (aIsDir && !bIsDir) return -1;
      if (!aIsDir && bIsDir) return 1;

      int comp = 0;
      switch (_sortBy) {
        case SftpSortBy.name:
          comp = a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
          break;
        case SftpSortBy.size:
          final aSize = a.attr.size ?? 0;
          final bSize = b.attr.size ?? 0;
          comp = aSize.compareTo(bSize);
          break;
        case SftpSortBy.date:
          final aTime = a.attr.modifyTime ?? 0;
          final bTime = b.attr.modifyTime ?? 0;
          comp = aTime.compareTo(bTime);
          break;
        case SftpSortBy.type:
          final aExt = a.filename.contains('.') ? a.filename.split('.').last.toLowerCase() : '';
          final bExt = b.filename.contains('.') ? b.filename.split('.').last.toLowerCase() : '';
          comp = aExt.compareTo(bExt);
          break;
      }

      return _sortAscending ? comp : -comp;
    });

    return list;
  }

  Future<void> _handleUploadFile() async {
    if (_sftp == null) return;
    final isIndo = context.read<SettingsProvider>().isIndonesian;

    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: isIndo ? 'Pilih Berkas untuk Diunggah' : 'Select File to Upload',
        type: FileType.any,
      );
      if (result.isEmpty) return;

      final pickedFile = result.first;
      final fileName = pickedFile.name;
      final remoteFilePath = _joinPath(_currentPath, fileName);

      final fileBytes = await pickedFile.xFile.readAsBytes();

      if (!mounted) return;
      _showProgressDialog(isIndo ? 'Mengunggah $fileName...' : 'Uploading $fileName...');

      final remoteFile = await _sftp!.open(
        remoteFilePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
      );

      await remoteFile.writeBytes(fileBytes);
      await remoteFile.close();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(isIndo ? '✅ Berhasil mengunggah $fileName (${_formatFileSize(fileBytes.length)})' : '✅ Uploaded $fileName (${_formatFileSize(fileBytes.length)})'),
        ),
      );

      await _loadDirectory(_currentPath);
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Upload failed: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleDownloadFile(SftpName item) async {
    if (_sftp == null) return;
    final isIndo = context.read<SettingsProvider>().isIndonesian;
    final fileName = item.filename;
    final remoteFilePath = _joinPath(_currentPath, fileName);

    try {
      _showProgressDialog(isIndo ? 'Mengunduh $fileName...' : 'Downloading $fileName...');

      final remoteFile = await _sftp!.open(remoteFilePath, mode: SftpFileOpenMode.read);
      final bytes = await remoteFile.readBytes();
      await remoteFile.close();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress dialog

      Uri? saveUri;
      try {
        saveUri = await FilePicker.saveFile(
          dialogTitle: isIndo ? 'Simpan berkas unduhan' : 'Save downloaded file',
          fileName: fileName,
          bytes: bytes,
        );
      } catch (_) {}

      String? savePath;
      if (saveUri != null) {
        try {
          savePath = saveUri.toFilePath();
        } catch (_) {
          savePath = saveUri.toString();
        }
      }

      if (saveUri == null) {
        // Fallback: save to Downloads folder
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null && home.isNotEmpty) {
          final downloadsDir = Directory('$home/Downloads');
          if (downloadsDir.existsSync()) {
            savePath = '${downloadsDir.path}/$fileName';
            final localFile = File(savePath);
            await localFile.writeAsBytes(bytes);
          }
        }
      }

      if (savePath != null || saveUri != null) {
        if (!mounted) return;
        final displayTarget = savePath ?? fileName;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(isIndo
                ? '✅ Berkas tersimpan di: $displayTarget (${_formatFileSize(bytes.length)})'
                : '✅ File saved to: $displayTarget (${_formatFileSize(bytes.length)})'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Download failed: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleViewOrEditFile(SftpName item) async {
    if (_sftp == null) return;
    final isIndo = context.read<SettingsProvider>().isIndonesian;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileName = item.filename;
    final remoteFilePath = _joinPath(_currentPath, fileName);
    final fileSize = item.attr.size ?? 0;

    // Check size threshold for text editor (limit to 3MB)
    if (fileSize > 3 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isIndo
              ? 'Berkas terlalu besar (${_formatFileSize(fileSize)}) untuk editor teks. Silakan unduh berkas langsung.'
              : 'File is too large (${_formatFileSize(fileSize)}) for inline text editor. Please download the file instead.'),
        ),
      );
      return;
    }

    _showProgressDialog(isIndo ? 'Membuka $fileName...' : 'Opening $fileName...');

    try {
      final remoteFile = await _sftp!.open(remoteFilePath, mode: SftpFileOpenMode.read);
      final bytes = await remoteFile.readBytes();
      await remoteFile.close();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress dialog

      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = String.fromCharCodes(bytes);
      }

      if (!mounted) return;
      _showEditorDialog(
        fileName: fileName,
        filePath: remoteFilePath,
        initialContent: content,
        isDark: isDark,
        isIndo: isIndo,
      );
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Failed to read file: $e'),
          ),
        );
      }
    }
  }

  void _showEditorDialog({
    required String fileName,
    required String filePath,
    required String initialContent,
    required bool isDark,
    required bool isIndo,
  }) {
    final controller = TextEditingController(text: initialContent);
    bool isSaving = false;
    bool hasUnsavedChanges = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final lines = '\n'.allMatches(controller.text).length + 1;
          final chars = controller.text.length;

          return Dialog.fullscreen(
            child: Scaffold(
              backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    if (hasUnsavedChanges) {
                      _showDiscardConfirmDialog(ctx, isIndo, () {
                        Navigator.of(dialogCtx).pop();
                      });
                    } else {
                      Navigator.of(dialogCtx).pop();
                    }
                  },
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_getFileIcon(fileName, false), size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          fileName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        if (hasUnsavedChanges) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isIndo ? 'MODIFIKASI' : 'MODIFIED',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.warning),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      filePath,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                actions: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '$lines ${isIndo ? "baris" : "lines"} • ${_formatFileSize(chars)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setDialogState(() => isSaving = true);
                              try {
                                final newBytes = utf8.encode(controller.text);
                                final remoteFile = await _sftp!.open(
                                  filePath,
                                  mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
                                );
                                await remoteFile.writeBytes(Uint8List.fromList(newBytes));
                                await remoteFile.close();

                                setDialogState(() {
                                  isSaving = false;
                                  hasUnsavedChanges = false;
                                });

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.success,
                                      content: Text(isIndo
                                          ? '✅ Perubahan berhasil disimpan ke $fileName'
                                          : '✅ Saved changes to $fileName'),
                                    ),
                                  );
                                  await _loadDirectory(_currentPath);
                                }
                              } catch (e) {
                                setDialogState(() => isSaving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.danger,
                                      content: Text('Failed to save file: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.save_rounded, size: 16),
                      label: Text(
                        isIndo ? 'SIMPAN' : 'SAVE',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      if (!hasUnsavedChanges) {
                        setDialogState(() => hasUnsavedChanges = true);
                      }
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDiscardConfirmDialog(BuildContext context, bool isIndo, VoidCallback onDiscard) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIndo ? 'Buang Perubahan?' : 'Discard Changes?'),
        content: Text(isIndo
            ? 'Ada perubahan berkas yang belum disimpan. Tetap tutup tanpa menyimpan?'
            : 'You have unsaved changes in this file. Close without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isIndo ? 'Batal' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onDiscard();
            },
            child: Text(isIndo ? 'Ya, Buang' : 'Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateFolder() async {
    if (_sftp == null) return;
    final isIndo = context.read<SettingsProvider>().isIndonesian;
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.create_new_folder_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Text(isIndo ? 'Buat Folder Baru' : 'Create New Folder'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isIndo ? 'Nama folder (e.g. logs_backup)' : 'Folder name (e.g. logs_backup)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isIndo ? 'Batal' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(isIndo ? 'Buat' : 'Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final newDirPath = _joinPath(_currentPath, name);
      try {
        await _sftp!.mkdir(newDirPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(isIndo ? '✅ Folder "$name" dibuat.' : '✅ Folder "$name" created.'),
            ),
          );
          await _loadDirectory(_currentPath);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppColors.danger, content: Text('Failed to create folder: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleCreateFile() async {
    if (_sftp == null) return;
    final isIndo = context.read<SettingsProvider>().isIndonesian;
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.note_add_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(isIndo ? 'Buat Berkas Baru' : 'Create New File'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isIndo ? 'Nama berkas (e.g. config.env)' : 'File name (e.g. config.env)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isIndo ? 'Batal' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(isIndo ? 'Buat' : 'Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final newFilePath = _joinPath(_currentPath, name);
      try {
        final file = await _sftp!.open(
          newFilePath,
          mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
        );
        await file.close();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(isIndo ? '✅ Berkas "$name" dibuat.' : '✅ File "$name" created.'),
            ),
          );
          await _loadDirectory(_currentPath);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppColors.danger, content: Text('Failed to create file: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleRenameItem(SftpName item) async {
    if (_sftp == null) return;
    final isIndo = context.read<SettingsProvider>().isIndonesian;
    final controller = TextEditingController(text: item.filename);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIndo ? 'Ganti Nama' : 'Rename Item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isIndo ? 'Batal' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(isIndo ? 'Simpan' : 'Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != item.filename) {
      final oldPath = _joinPath(_currentPath, item.filename);
      final newPath = _joinPath(_currentPath, newName);

      try {
        await _sftp!.rename(oldPath, newPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(isIndo ? '✅ Nama diubah menjadi "$newName".' : '✅ Renamed to "$newName".'),
            ),
          );
          await _loadDirectory(_currentPath);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppColors.danger, content: Text('Rename failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleDeleteItem(SftpName item) async {
    if (_sftp == null) return;
    final isIndo = context.read<SettingsProvider>().isIndonesian;
    final isDir = item.attr.isDirectory;
    final name = item.filename;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 22),
            const SizedBox(width: 8),
            Text(isIndo ? 'Hapus ${isDir ? "Folder" : "Berkas"}?' : 'Delete ${isDir ? "Folder" : "File"}?'),
          ],
        ),
        content: Text(isIndo
            ? 'Apakah Anda yakin ingin menghapus "$name"? Tindakan ini permanen.'
            : 'Are you sure you want to permanently delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isIndo ? 'Batal' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isIndo ? 'Ya, Hapus' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final targetPath = _joinPath(_currentPath, name);
      try {
        if (isDir) {
          await _sftp!.rmdir(targetPath);
        } else {
          await _sftp!.remove(targetPath);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(isIndo ? '🗑️ "$name" berhasil dihapus.' : '🗑️ "$name" deleted.'),
            ),
          );
          await _loadDirectory(_currentPath);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppColors.danger, content: Text('Delete failed: $e')),
          );
        }
      }
    }
  }

  void _showItemDetailsDialog(SftpName item) {
    final isIndo = context.read<SettingsProvider>().isIndonesian;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fullPath = _joinPath(_currentPath, item.filename);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(_getFileIcon(item.filename, item.attr.isDirectory), size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.filename,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(isIndo ? 'Lokasi' : 'Path', fullPath, isDark),
            _buildDetailRow(isIndo ? 'Tipe' : 'Type', item.attr.isDirectory ? 'Directory' : (item.attr.isSymbolicLink ? 'Symbolic Link' : 'Regular File'), isDark),
            _buildDetailRow(isIndo ? 'Ukuran' : 'Size', '${_formatFileSize(item.attr.size)} (${item.attr.size ?? 0} bytes)', isDark),
            _buildDetailRow(isIndo ? 'Izin (Mode)' : 'Permissions', '${_formatPermissions(item.attr)} (${_formatOctalPermissions(item.attr)})', isDark),
            _buildDetailRow(isIndo ? 'Dimodifikasi' : 'Modified', _formatModifiedTime(item.attr.modifyTime), isDark),
            _buildDetailRow('UID / GID', '${item.attr.userID ?? "--"} : ${item.attr.groupID ?? "--"}', isDark),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: fullPath));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isIndo ? 'Path disalin ke clipboard' : 'Path copied to clipboard')),
              );
            },
            child: Text(isIndo ? 'Salin Path' : 'Copy Path'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleJumpToPath() async {
    final isIndo = context.read<SettingsProvider>().isIndonesian;
    final controller = TextEditingController(text: _currentPath);

    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIndo ? 'Lompat ke Path' : 'Jump to Path'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                hintText: '/var/www atau /etc',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isIndo ? 'Bookmark Cepat:' : 'Quick Bookmarks:',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildBookmarkChip(ctx, controller, '/', 'Root'),
                _buildBookmarkChip(ctx, controller, '/home/${widget.server.username}', 'Home'),
                _buildBookmarkChip(ctx, controller, '/etc', 'etc'),
                _buildBookmarkChip(ctx, controller, '/var/log', 'Logs'),
                _buildBookmarkChip(ctx, controller, '/var/www', 'Web'),
                _buildBookmarkChip(ctx, controller, '/tmp', 'Tmp'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isIndo ? 'Batal' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(isIndo ? 'Buka' : 'Go'),
          ),
        ],
      ),
    );

    if (path != null && path.isNotEmpty) {
      await _loadDirectory(path);
    }
  }

  Widget _buildBookmarkChip(BuildContext ctx, TextEditingController ctrl, String path, String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        ctrl.text = path;
      },
    );
  }

  void _showProgressDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '--';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatPermissions(SftpFileAttrs? attr) {
    if (attr == null || attr.mode == null) return '----------';
    final m = attr.mode!.value;
    final isDir = attr.isDirectory;
    final isLink = attr.isSymbolicLink;

    final typeChar = isDir ? 'd' : (isLink ? 'l' : '-');

    String rwx(int shift) {
      final r = (m & (4 << shift)) != 0 ? 'r' : '-';
      final w = (m & (2 << shift)) != 0 ? 'w' : '-';
      final x = (m & (1 << shift)) != 0 ? 'x' : '-';
      return '$r$w$x';
    }

    return '$typeChar${rwx(6)}${rwx(3)}${rwx(0)}';
  }

  String _formatOctalPermissions(SftpFileAttrs? attr) {
    if (attr == null || attr.mode == null) return '0644';
    final m = attr.mode!.value & 0x1FF;
    return '0${m.toRadixString(8)}';
  }

  String _formatModifiedTime(int? timestamp) {
    if (timestamp == null) return '--';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final d = date.day.toString().padLeft(2, '0');
    final m = _getMonthName(date.month);
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');

    if (date.year == now.year) {
      return '$d $m $h:$min';
    } else {
      return '$d $m ${date.year}';
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  IconData _getFileIcon(String filename, bool isDirectory) {
    if (isDirectory) return Icons.folder_rounded;

    final lower = filename.toLowerCase();
    if (lower.endsWith('.sh') || lower.endsWith('.bash') || lower.endsWith('.zsh')) return Icons.terminal_rounded;
    if (lower.endsWith('.py') || lower.endsWith('.dart') || lower.endsWith('.js') || lower.endsWith('.ts') || lower.endsWith('.php') || lower.endsWith('.go') || lower.endsWith('.c') || lower.endsWith('.cpp')) return Icons.code_rounded;
    if (lower.endsWith('.conf') || lower.endsWith('.cfg') || lower.endsWith('.ini') || lower.endsWith('.env') || lower.endsWith('.yaml') || lower.endsWith('.yml') || lower.endsWith('.json') || lower.endsWith('.xml')) return Icons.settings_suggest_rounded;
    if (lower.endsWith('.log') || lower.endsWith('.txt') || lower.endsWith('.out')) return Icons.receipt_long_rounded;
    if (lower.endsWith('.tar') || lower.endsWith('.gz') || lower.endsWith('.zip') || lower.endsWith('.bz2') || lower.endsWith('.7z')) return Icons.folder_zip_rounded;
    if (lower.endsWith('.key') || lower.endsWith('.pem') || lower.endsWith('.pub') || lower.endsWith('.crt') || lower.endsWith('.cer')) return Icons.vpn_key_rounded;
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.svg') || lower.endsWith('.gif')) return Icons.image_rounded;
    if (lower.endsWith('.sql') || lower.endsWith('.db') || lower.endsWith('.sqlite')) return Icons.dns_rounded;
    if (lower.endsWith('.md')) return Icons.article_rounded;

    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String filename, bool isDirectory) {
    if (isDirectory) return AppColors.warning;

    final lower = filename.toLowerCase();
    if (lower.endsWith('.sh') || lower.endsWith('.bash') || lower.endsWith('.py') || lower.endsWith('.dart') || lower.endsWith('.js') || lower.endsWith('.php')) return AppColors.success;
    if (lower.endsWith('.conf') || lower.endsWith('.cfg') || lower.endsWith('.env') || lower.endsWith('.yaml') || lower.endsWith('.json')) return AppColors.primary;
    if (lower.endsWith('.log') || lower.endsWith('.txt')) return AppColors.info;
    if (lower.endsWith('.tar') || lower.endsWith('.gz') || lower.endsWith('.zip')) return AppColors.purple;
    if (lower.endsWith('.key') || lower.endsWith('.pem') || lower.endsWith('.pub')) return AppColors.danger;

    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final settings = context.watch<SettingsProvider>();
    final isIndo = settings.isIndonesian;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_shared_rounded, color: AppColors.purple, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'SFTP FILE MANAGER',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              '${widget.server.name} (${widget.server.username}@${widget.server.host}:${widget.server.port})',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Quick Terminal Jump
          IconButton(
            icon: const Icon(Icons.terminal_rounded, size: 20),
            tooltip: isIndo ? 'Buka Terminal SSH' : 'Open SSH Terminal',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TerminalScreen(server: widget.server),
                ),
              );
            },
          ),
          // Refresh Directory
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: isIndo ? 'Segarkan' : 'Refresh',
            onPressed: _connectionState == SftpConnectionState.connected
                ? () => _loadDirectory(_currentPath)
                : _initSftpConnection,
          ),
          // More Menu (Upload, New Folder, New File, Hidden toggle)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              switch (val) {
                case 'upload':
                  _handleUploadFile();
                  break;
                case 'new_folder':
                  _handleCreateFolder();
                  break;
                case 'new_file':
                  _handleCreateFile();
                  break;
                case 'toggle_hidden':
                  setState(() => _showHiddenFiles = !_showHiddenFiles);
                  break;
                case 'jump':
                  _handleJumpToPath();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'upload',
                child: Row(
                  children: [
                    const Icon(Icons.upload_file_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(isIndo ? 'Unggah Berkas' : 'Upload File'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'new_folder',
                child: Row(
                  children: [
                    const Icon(Icons.create_new_folder_rounded, size: 18, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Text(isIndo ? 'Folder Baru' : 'New Folder'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'new_file',
                child: Row(
                  children: [
                    const Icon(Icons.note_add_rounded, size: 18, color: AppColors.success),
                    const SizedBox(width: 10),
                    Text(isIndo ? 'Berkas Baru' : 'New File'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'toggle_hidden',
                child: Row(
                  children: [
                    Icon(_showHiddenFiles ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                    const SizedBox(width: 10),
                    Text(_showHiddenFiles
                        ? (isIndo ? 'Sembunyikan Berkas Titik (.)' : 'Hide Dotfiles (.)')
                        : (isIndo ? 'Tampilkan Berkas Titik (.)' : 'Show Dotfiles (.)')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'jump',
                child: Row(
                  children: [
                    const Icon(Icons.drive_file_move_rounded, size: 18),
                    const SizedBox(width: 10),
                    Text(isIndo ? 'Lompat ke Path...' : 'Jump to Path...'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(theme, isDark, isIndo),
      floatingActionButton: _connectionState == SftpConnectionState.connected
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              onPressed: _handleUploadFile,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(
                isIndo ? 'UNGGAH BERKAS' : 'UPLOAD FILE',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 0.5),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark, bool isIndo) {
    if (_connectionState == SftpConnectionState.connecting) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.purple),
              ),
              const SizedBox(height: 16),
              Text(
                isIndo
                    ? 'Menghubungkan sesi SFTP ke ${widget.server.name}...'
                    : 'Establishing SFTP connection to ${widget.server.name}...',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.server.username}@${widget.server.host}:${widget.server.port}',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_connectionState == SftpConnectionState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                isIndo ? 'Gagal Terhubung ke SFTP' : 'SFTP Connection Failed',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: _initSftpConnection,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(isIndo ? 'Coba Hubungkan Kembali' : 'Retry Connection'),
              ),
            ],
          ),
        ),
      );
    }

    // Connected: Path breadcrumb + Toolbar + Directory Listing
    final items = _filteredAndSortedItems;

    return Column(
      children: [
        // Path navigation bar & Breadcrumbs
        _buildPathBar(theme, isDark, isIndo),

        // Search & Filter Toolbar
        _buildToolbar(theme, isDark, isIndo),

        // Directory List
        Expanded(
          child: _isLoadingDirectory
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.purple),
                  ),
                )
              : _directoryError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_off_rounded, size: 36, color: AppColors.danger),
                            const SizedBox(height: 10),
                            Text(
                              _directoryError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => _loadDirectory(_getParentPath(_currentPath)),
                              child: Text(isIndo ? 'Kembali ke Direktori Induk' : 'Go to Parent Directory'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : items.isEmpty && _currentPath == '/'
                      ? Center(
                          child: Text(
                            isIndo ? 'Direktori kosong.' : 'Directory is empty.',
                            style: TextStyle(color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          itemCount: (_currentPath != '/' ? 1 : 0) + items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, index) {
                            // First item is ".." parent navigation when not at root
                            if (_currentPath != '/' && index == 0) {
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.arrow_upward_rounded, color: AppColors.primary, size: 20),
                                title: const Text(
                                  '..',
                                  style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 13.5),
                                ),
                                subtitle: Text(
                                  isIndo ? 'Direktori sebelumnya' : 'Parent directory',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                                onTap: () => _loadDirectory(_getParentPath(_currentPath)),
                              );
                            }

                            final itemIndex = _currentPath != '/' ? index - 1 : index;
                            final item = items[itemIndex];
                            final isDir = item.attr.isDirectory;

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _getFileColor(item.filename, isDir).withValues(alpha: isDark ? 0.15 : 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getFileIcon(item.filename, isDir),
                                  size: 19,
                                  color: _getFileColor(item.filename, isDir),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.filename,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12.5,
                                        fontWeight: isDir ? FontWeight.w800 : FontWeight.w600,
                                        color: isDir
                                            ? (isDark ? AppColors.warning : AppColors.warningLight)
                                            : theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (item.attr.isSymbolicLink)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.info.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('LINK', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.info)),
                                    ),
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    _formatPermissions(item.attr),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '•',
                                    style: TextStyle(color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isDir ? 'Folder' : _formatFileSize(item.attr.size),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '•',
                                    style: TextStyle(color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatModifiedTime(item.attr.modifyTime),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 18),
                                onSelected: (action) {
                                  switch (action) {
                                    case 'open':
                                      if (isDir) {
                                        _loadDirectory(_joinPath(_currentPath, item.filename));
                                      } else {
                                        _handleViewOrEditFile(item);
                                      }
                                      break;
                                    case 'download':
                                      _handleDownloadFile(item);
                                      break;
                                    case 'rename':
                                      _handleRenameItem(item);
                                      break;
                                    case 'details':
                                      _showItemDetailsDialog(item);
                                      break;
                                    case 'delete':
                                      _handleDeleteItem(item);
                                      break;
                                  }
                                },
                                itemBuilder: (popupCtx) => [
                                  PopupMenuItem(
                                    value: 'open',
                                    child: Row(
                                      children: [
                                        Icon(isDir ? Icons.folder_open_rounded : Icons.edit_note_rounded, size: 17),
                                        const SizedBox(width: 10),
                                        Text(isDir ? (isIndo ? 'Buka Folder' : 'Open Folder') : (isIndo ? 'Buka / Edit Berkas' : 'View / Edit File')),
                                      ],
                                    ),
                                  ),
                                  if (!isDir)
                                    PopupMenuItem(
                                      value: 'download',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.download_rounded, size: 17, color: AppColors.primary),
                                          const SizedBox(width: 10),
                                          Text(isIndo ? 'Unduh Berkas' : 'Download File'),
                                        ],
                                      ),
                                    ),
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.drive_file_rename_outline_rounded, size: 17),
                                        const SizedBox(width: 10),
                                        Text(isIndo ? 'Ganti Nama' : 'Rename'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'details',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline_rounded, size: 17),
                                        const SizedBox(width: 10),
                                        Text(isIndo ? 'Detail Berkas' : 'File Info'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.danger),
                                        const SizedBox(width: 10),
                                        Text(
                                          isIndo ? 'Hapus' : 'Delete',
                                          style: const TextStyle(color: AppColors.danger),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                if (isDir) {
                                  _loadDirectory(_joinPath(_currentPath, item.filename));
                                } else {
                                  _handleViewOrEditFile(item);
                                }
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildPathBar(ThemeData theme, bool isDark, bool isIndo) {
    // Generate breadcrumbs from _currentPath
    final segments = _currentPath.split('/').where((s) => s.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        children: [
          // Jump to root or parent button
          InkWell(
            onTap: () => _loadDirectory('/'),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.computer_rounded,
                size: 18,
                color: isDark ? AppColors.primary : AppColors.primaryLight,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Scrollable breadcrumb path
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _loadDirectory('/'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        '/',
                        style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                  for (int i = 0; i < segments.length; i++) ...[
                    Text(
                      '/',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        fontSize: 12,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        final targetPath = '/${segments.sublist(0, i + 1).join('/')}';
                        _loadDirectory(targetPath);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          segments[i],
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: i == segments.length - 1 ? FontWeight.w800 : FontWeight.w500,
                            color: i == segments.length - 1
                                ? (isDark ? AppColors.primary : AppColors.primaryLight)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Jump button
          IconButton(
            icon: const Icon(Icons.edit_location_alt_rounded, size: 17),
            tooltip: isIndo ? 'Ketik Path Langsung' : 'Edit Path',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: _handleJumpToPath,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme, bool isDark, bool isIndo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        children: [
          // Search input field
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: isIndo ? 'Cari berkas di sini...' : 'Search in this folder...',
                  hintStyle: TextStyle(fontSize: 11.5, color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 14),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Sort option menu
          PopupMenuButton<SftpSortBy>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 14,
                  color: isDark ? AppColors.primary : AppColors.primaryLight,
                ),
                const SizedBox(width: 2),
                const Icon(Icons.sort_rounded, size: 16),
              ],
            ),
            tooltip: isIndo ? 'Urutkan' : 'Sort by',
            onSelected: (option) {
              setState(() {
                if (_sortBy == option) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = option;
                  _sortAscending = true;
                }
              });
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: SftpSortBy.name,
                child: Text(isIndo ? 'Nama' : 'Name'),
              ),
              PopupMenuItem(
                value: SftpSortBy.size,
                child: Text(isIndo ? 'Ukuran' : 'Size'),
              ),
              PopupMenuItem(
                value: SftpSortBy.date,
                child: Text(isIndo ? 'Tanggal Modifikasi' : 'Modified Date'),
              ),
              PopupMenuItem(
                value: SftpSortBy.type,
                child: Text(isIndo ? 'Tipe Ekstensi' : 'Extension Type'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
