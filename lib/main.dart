import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'tflite_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AquaScan',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TFLiteService _tfliteService = TFLiteService();
  final ImagePicker _picker = ImagePicker();
  
  File? _image;
  bool _isLoading = false;
  bool _isModelLoaded = false;
  Map<String, double>? _results;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    await _tfliteService.loadModel();
    setState(() {
      _isModelLoaded = true;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _results = null; // Reset hasil sebelumnya
      });
    }
  }

  Future<void> _predictImage() async {
    if (_image == null) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _tfliteService.predict(_image!);
      setState(() {
        _results = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tfliteService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AquaScan - Deteksi Sampah Air'),
        centerTitle: true,
      ),
      body: !_isModelLoaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gambar Preview
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_image!, fit: BoxFit.cover),
                          )
                        : const Center(
                            child: Text('Belum ada gambar dipilih'),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Tombol Pilih Gambar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Kamera'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galeri'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tombol Analisis
                  ElevatedButton(
                    onPressed: _image == null || _isLoading ? null : _predictImage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Analisis Gambar', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),

                  // Hasil Prediksi
                  if (_results != null) ...[
                    const Text(
                      'Hasil Deteksi:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._results!.entries.map((entry) {
                      return Card(
                        child: ListTile(
                          title: Text(entry.key),
                          trailing: Text(
                            '${(entry.value * 100).toStringAsFixed(2)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
    );
  }
}