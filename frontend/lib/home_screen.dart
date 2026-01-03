import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  List<dynamic> _files = [];
  bool _isLoading = false;
  String _currentFolder = "My Doc"; // Default root
  List<String> _folderPath = [];

  @override
  void initState() {
    super.initState();
    _refreshFiles();
  }

  Future<bool> _onWillPop() async {
    if (_folderPath.isNotEmpty) {
      setState(() {
        _currentFolder = _folderPath.removeLast();
      });
      _refreshFiles();
      return false; // Don't exit app
    }
    return true; // Exit app
  }

  Future<void> _refreshFiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final files = await _apiService.getFiles(folderName: _currentFolder);
      if (!mounted) return;
      setState(() {
        _files = files;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading files: $e')));
      print(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scanDocument() async {
    try {
      final options = DocumentScannerOptions(
        mode: ScannerMode.filter,
        isGalleryImport: true,
        pageLimit: 10,
      );

      final scanner = DocumentScanner(options: options);
      final result = await scanner.scanDocument();

      if (!mounted) return;

      if (result.pdf != null) {
        // PDF returned
        final file = File(result.pdf!.uri);
        await _uploadScannedFiles([file], isPdf: true);
      } else if (result.images.isNotEmpty) {
        // Images returned
        List<File> files = result.images.map((img) => File(img)).toList();
        await _uploadScannedFiles(files, isPdf: false);
      }

      scanner.close();
    } catch (e) {
      print("Error scanning: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanning failed or cancelled'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadScannedFiles(
    List<File> files, {
    bool isPdf = false,
  }) async {
    if (!mounted) return;

    // Confirm Upload Dialog
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Upload Scanned Document?'),
        content: Text(
          'Keep as ${isPdf ? "PDF" : "${files.length} Images"}.\nTarget: $_currentFolder',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Processing...'),
                  duration: const Duration(days: 1),
                ),
              );

              try {
                final newFiles = await _apiService.uploadFiles(
                  files,
                  _currentFolder,
                );

                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                setState(() {
                  _files.addAll(newFiles);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Success!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Upload Failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder() async {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Create Folder'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "Folder Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                Navigator.pop(dialogContext);

                if (!mounted) return;

                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Creating...'),
                      duration: Duration(days: 1),
                    ),
                  );
                  final newFolder = await _apiService.createFolder(
                    controller.text,
                    parentFolder: _currentFolder,
                  );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Folder Created'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  setState(() {
                    _files.add(newFolder);
                  });
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create folder: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameFile(Map<String, dynamic> file) async {
    final controller = TextEditingController(text: file['name']);

    showDialog(
      context: context,
      builder: (dialogContext) {
        // ✅ Apply selection AFTER TextField is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final dotIndex = file['name'].lastIndexOf('.');
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: dotIndex > 0 ? dotIndex : file['name'].length,
          );
        });

        return AlertDialog(
          title: Text('Rename ${file['type'] == 'folder' ? 'Folder' : 'File'}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "New Name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isNotEmpty &&
                    controller.text != file['name']) {
                  Navigator.pop(dialogContext);

                  if (!mounted) return;

                  try {
                    final messenger = ScaffoldMessenger.of(context);

                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Renaming...'),
                        duration: Duration(days: 1),
                      ),
                    );

                    await _apiService.renameFile(file['id'], controller.text);

                    if (!mounted) return;

                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Renamed Successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Optimistic update
                    setState(() {
                      final index = _files.indexWhere(
                        (f) => f['id'] == file['id'],
                      );
                      if (index != -1) {
                        _files[index]['name'] = controller.text;
                      }
                    });
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rename Failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFile(String id) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleting...'), duration: Duration(days: 1)),
      );
      await _apiService.deleteFile(id);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted'), backgroundColor: Colors.green),
      );
      _refreshFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickAndUpload({bool imagesOnly = false}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: imagesOnly ? FileType.image : FileType.any,
    );

    if (result != null) {
      List<File> files = result.paths.map((path) => File(path!)).toList();
      String fileNames = result.files.map((f) => f.name).join(', ');
      String action = imagesOnly ? "Convert to PDF & Upload" : "Upload";

      if (!mounted) return;

      // Confirm Upload Dialog
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(action),
          content: Text(
            'Selected ${files.length} files ($fileNames).\nTarget: $_currentFolder',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // Use the HomeScreen's context, not the dialog's
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Processing...'),
                    duration: const Duration(
                      days: 1,
                    ), // Indefinite until hidden
                  ),
                );

                try {
                  final newFiles = await _apiService.uploadFiles(
                    files,
                    _currentFolder,
                  );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();

                  // Optimistic Update: Add to list immediately
                  setState(() {
                    _files.addAll(newFiles);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Success!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Upload Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Upload'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentFolder),
          leading: _folderPath.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () async {
                    await _onWillPop();
                  },
                )
              : null,
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => _authService.signOut(),
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshFiles,
                child: ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    return ListTile(
                      leading: Icon(
                        file['type'] == 'folder'
                            ? Icons.folder
                            : Icons.insert_drive_file,
                        color: file['type'] == 'folder'
                            ? Colors.amber
                            : Colors.blue,
                      ),
                      title: Text(file['name']),
                      onTap: () async {
                        if (file['type'] == 'folder') {
                          // Navigate into folder
                          setState(() {
                            _folderPath.add(_currentFolder);
                            _currentFolder = file['name'];
                            _refreshFiles();
                          });
                        } else {
                          // Open file
                          final link = file['webViewLink'];
                          if (link != null) {
                            final uri = Uri.parse(link);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not open file'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'No link available for this file',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      contentPadding: EdgeInsets.only(left: 16, right: 0),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteFile(file['id']);
                          } else if (value == 'rename') {
                            _renameFile(file);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "scan",
              onPressed: _scanDocument,
              tooltip: "Scan Document",
              child: Icon(Icons.camera_alt),
            ),
            SizedBox(height: 10),
            FloatingActionButton(
              heroTag: "upload",
              onPressed: () => _pickAndUpload(imagesOnly: true),
              tooltip: "Upload Any File",
              child: Icon(Icons.upload_file),
            ),
            SizedBox(height: 10),
            FloatingActionButton(
              heroTag: "folder",
              onPressed: _createFolder,
              tooltip: "Create Folder",
              child: Icon(Icons.create_new_folder),
            ),
          ],
        ),
      ),
    );
  }
}
