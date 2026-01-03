import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  // Use 10.0.2.2 for Android emulator to access localhost of the host machine.
  // For iOS emulator use localhost.
  // Make sure this matches your environment.
  static const String baseUrl = 'https://backend-h1ef.onrender.com';
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<List<dynamic>> uploadFiles(
    List<File> files,
    String folderName, {
    String? folderId,
  }) async {
    var uri = Uri.parse('$baseUrl/upload');
    var request = http.MultipartRequest('POST', uri);

    // Add headers to multipart request
    final headers = await _getHeaders();
    request.headers.addAll(headers);

    request.fields['folder_name'] = folderName;
    if (folderId != null) {
      request.fields['folder_id'] = folderId;
    }

    for (var file in files) {
      request.files.add(await http.MultipartFile.fromPath('files', file.path));
    }

    var response = await request.send();
    if (response.statusCode != 200) {
      final respStr = await response.stream.bytesToString();
      throw Exception('Failed to upload file: ${response.statusCode} $respStr');
    }

    final respStr = await response.stream.bytesToString();
    final data = jsonDecode(respStr);
    return data['uploaded'];
  }

  Future<Map<String, dynamic>> createFolder(
    String folderName, {
    String? parentFolder,
  }) async {
    var uri = Uri.parse('$baseUrl/create_folder');
    var response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: {
        'folder_name': folderName,
        if (parentFolder != null) 'parent_folder': parentFolder,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create folder: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['folder'];
  }

  Future<List<dynamic>> getFiles({String? folderName}) async {
    var uri = Uri.parse('$baseUrl/files');
    if (folderName != null) {
      uri = uri.replace(queryParameters: {'folder_name': folderName});
    }

    var response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['files'];
    } else {
      throw Exception('Failed to load files: ${response.body}');
    }
  }

  Future<void> deleteFile(String fileId) async {
    var uri = Uri.parse('$baseUrl/delete/$fileId');
    var response = await http.delete(uri, headers: await _getHeaders());

    if (response.statusCode != 200) {
      throw Exception('Failed to delete file: ${response.body}');
    }
  }

  Future<void> renameFile(String fileId, String newName) async {
    var uri = Uri.parse('$baseUrl/rename/$fileId');
    var response = await http.put(
      uri,
      headers: await _getHeaders(),
      body: {'new_name': newName},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to rename file: ${response.body}');
    }
  }
}
