import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(LiveStreamingApp());
}

class LiveStreamingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Streaming App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: WelcomePage(),
    );
  }
}

class WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 100, color: Colors.teal),
            SizedBox(height: 20),
            Text(
              'Live Streaming App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MainMenu()),
                );
              },
              child: Text('Enter'),
            ),
          ],
        ),
      ),
    );
  }
}

class MainMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Menu'),
        backgroundColor: Colors.teal,
      ),
      body: GridView.count(
        crossAxisCount: 2,
        children: [
          MenuOption('Watch', Icons.play_arrow, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LiveStreamScreen()),
            );
          }),
          MenuOption('Upload Images', Icons.upload, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UploadImagesScreen()),
            );
          }),
          MenuOption('Delete Images', Icons.delete, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DeleteImagesScreen()),
            );
          }),
        ],
      ),
    );
  }
}

class MenuOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  MenuOption(this.title, this.icon, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(10),
      child: InkWell(
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.teal),
            SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class LiveStreamScreen extends StatefulWidget {
  @override
  _LiveStreamScreenState createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.network(
      'http://yourserver.com/live/streamkey.m3u8',
    );
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: true,
      fullScreenByDefault: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.red,
        handleColor: Colors.redAccent,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.lightGreen,
      ),
      placeholder: Center(child: CircularProgressIndicator()),
      errorBuilder: (context, errorMessage) {
        return Center(child: Text(errorMessage));
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    _videoPlayerController.dispose();
    _chewieController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Streaming'),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: Chewie(
          controller: _chewieController,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: Icon(Icons.arrow_back),
      ),
    );
  }
}

class UploadImagesScreen extends StatefulWidget {
  @override
  _UploadImagesScreenState createState() => _UploadImagesScreenState();
}

class _UploadImagesScreenState extends State<UploadImagesScreen> {
  List<File> _images = [];

  Future<void> _pickImages(ImageSource source) async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        final pickedFiles = await picker.pickMultiImage();
        if (pickedFiles != null) {
          setState(() {
            _images = pickedFiles.map((file) => File(file.path)).toList();
          });
        }
      } else if (source == ImageSource.camera) {
        final pickedFile = await picker.pickImage(source: source);
        if (pickedFile != null) {
          setState(() {
            _images.add(File(pickedFile.path));
          });
        }
      }
      // Save images to app storage
      final directory = await getApplicationDocumentsDirectory();
      for (var image in _images) {
        final fileName = image.path.split('/').last;
        final newFile = File('${directory.path}/$fileName');
        await image.copy(newFile.path);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Images'),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: _images.isEmpty
            ? Text('No images uploaded', style: TextStyle(fontSize: 18))
            : ListView.builder(
          itemCount: _images.length,
          itemBuilder: (context, index) {
            return Image.file(_images[index]);
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => _pickImages(ImageSource.camera),
            child: Icon(Icons.camera_alt),
            backgroundColor: Colors.teal,
            heroTag: null,
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () => _pickImages(ImageSource.gallery),
            child: Icon(Icons.photo_library),
            backgroundColor: Colors.teal,
            heroTag: null,
          ),
        ],
      ),
    );
  }
}

class DeleteImagesScreen extends StatefulWidget {
  @override
  _DeleteImagesScreenState createState() => _DeleteImagesScreenState();
}

class _DeleteImagesScreenState extends State<DeleteImagesScreen> {
  List<File> _images = [];
  late Directory _appDirectory;
  late Directory _recycleBinDirectory;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    _appDirectory = await getApplicationDocumentsDirectory();
    _recycleBinDirectory = Directory('${_appDirectory.path}/recycle_bin');

    if (!_recycleBinDirectory.existsSync()) {
      _recycleBinDirectory.createSync();
    }

    final files = _appDirectory.listSync();
    setState(() {
      _images = files
          .whereType<File>()
          .toList(); // Only include files, no directories
    });
  }

  Future<void> _deleteImage(File image) async {
    final fileName = image.path.split('/').last;
    final recycleBinPath = '${_recycleBinDirectory.path}/$fileName';
    final recycledImage = File(recycleBinPath);

    if (await recycledImage.exists()) {
      await recycledImage.delete();
    }

    await image.rename(recycleBinPath); // Move to recycle bin

    setState(() {
      _images.remove(image);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delete Images'),
        backgroundColor: Colors.teal,
      ),
      body: _images.isEmpty
          ? Center(
        child: Text('No images available', style: TextStyle(fontSize: 18)),
      )
          : ListView.builder(
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final image = _images[index];
          return ListTile(
            leading: Image.file(image, width: 50, height: 50),
            title: Text(image.path.split('/').last),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteImage(image),
            ),
          );
        },
      ),
    );
  }
}
