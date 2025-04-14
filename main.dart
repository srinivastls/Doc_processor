import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

void main() => runApp(const DocApp());

class DocApp extends StatelessWidget {
  const DocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Ops',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FileSystemEntity> files = [];

  @override
  void initState() {
    super.initState();
    loadFiles();
  }

  Future<void> loadFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final myDir = Directory("${dir.path}/docs");
    if (!myDir.existsSync()) myDir.createSync();
    final f = myDir.listSync();
    setState(() {
      files = f;
    });
  }

  Future<void> pickAndSaveFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final pickedFile = File(result.files.single.path!);
      final dir = await getApplicationDocumentsDirectory();
      final docsDir = Directory("${dir.path}/docs");
      if (!docsDir.existsSync()) docsDir.createSync();
      final newFile = File("${docsDir.path}/${pickedFile.uri.pathSegments.last}");
      await pickedFile.copy(newFile.path);
      loadFiles();
    }
  }

  void openFile(FileSystemEntity file) async {
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cannot open this file type.")),
      );
    }
  }

  void deleteFile(FileSystemEntity file) {
    file.deleteSync();
    loadFiles();
  }

  void convertToPDF(FileSystemEntity file) async {
    final pdf = pw.Document();
    final content = await File(file.path).readAsString();
    pdf.addPage(pw.Page(build: (pw.Context ctx) => pw.Padding(
      padding: const pw.EdgeInsets.all(20),
      child: pw.Text(content),
    )));
    final dir = await getApplicationDocumentsDirectory();
    final filename = file.uri.pathSegments.last.split(".").first;
    final pdfFile = File("${dir.path}/docs/${filename}_converted.pdf");
    await pdfFile.writeAsBytes(await pdf.save());
    loadFiles();
  }

  void shareFile(FileSystemEntity file) {
    Share.shareFiles([file.path]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Document Ops")),
      body: files.isEmpty
          ? const Center(child: Text("No documents found."))
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return ListTile(
                  title: Text(file.uri.pathSegments.last),
                  onTap: () => openFile(file),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') deleteFile(file);
                      else if (value == 'pdf') convertToPDF(file);
                      else if (value == 'share') shareFile(file);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'pdf', child: Text("Convert to PDF")),
                      const PopupMenuItem(value: 'share', child: Text("Share")),
                      const PopupMenuItem(value: 'delete', child: Text("Delete")),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: pickAndSaveFile,
        child: const Icon(Icons.upload_file),
      ),
    );
  }
}
