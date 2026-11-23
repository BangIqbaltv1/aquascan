import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'tflite_service.dart';
import 'database_helper.dart';

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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Menggunakan IndexedStack agar state tidak hilang saat pindah tab
  final List<Widget> _pages = [
    const ScanPage(),
    const HistoryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
        ],
      ),
    );
  }
}

// ==========================================
// HALAMAN SCAN (Kamera & Prediksi)
// ==========================================
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final TFLiteService _tfliteService = TFLiteService();
  final ImagePicker _picker = ImagePicker();
  final DatabaseHelper _dbHelper = DatabaseHelper();

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
        _results = null;
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

  Future<void> _saveToHistory() async {
    if (_results == null) return;
    
    // Ambil kelas dengan probabilitas tertinggi
    var topEntry = _results!.entries.reduce((a, b) => a.value > b.value ? a : b);
    
    History history = History(
      label: topEntry.key,
      confidence: topEntry.value,
      timestamp: DateTime.now().toString().substring(0, 19),
    );

    await _dbHelper.insertHistory(history);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasil berhasil disimpan ke Riwayat!')),
      );
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
      appBar: AppBar(title: const Text('AquaScan - Deteksi'), centerTitle: true),
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
                        : const Center(child: Text('Belum ada gambar dipilih')),
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
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _saveToHistory,
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan ke Riwayat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ==========================================
// HALAMAN RIWAYAT (Database SQLite)
// ==========================================
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<History> _histories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final histories = await _dbHelper.getHistory();
    setState(() {
      _histories = histories;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Deteksi'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _histories.isEmpty
              ? const Center(child: Text('Belum ada riwayat deteksi.'))
              : ListView.builder(
                  itemCount: _histories.length,
                  itemBuilder: (context, index) {
                    final item = _histories[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.water_drop, color: Colors.blue),
                        title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Akurasi: ${(item.confidence * 100).toStringAsFixed(2)}%\nWaktu: ${item.timestamp}'),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}