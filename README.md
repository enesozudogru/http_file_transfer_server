# HTTP File Transfer Server

Basit ve temiz bir HTTP dosya transfer sunucusu Flutter paketi. Delegate pattern karmaşası olmadan, doğrudan kullanılabilir.

## Özellikler

- ✅ Basit ve temiz API
- ✅ Dosya yükleme ve indirme
- ✅ Web arayüzü dahil
- ✅ Video ve ses dosyası desteği
- ✅ Otomatik cihaz ismini algılama
- ✅ Çeviriler desteği
- ✅ Delegate pattern yok - karışık kod yok

## Kurulum

`pubspec.yaml` dosyasına ekleyin:

```yaml
dependencies:
  http_file_transfer_server: ^0.0.1
```

## Temel Kullanım

```dart
import 'dart:io';
import 'package:http_file_transfer_server/http_file_transfer_server.dart';

// Sunucu oluştur
final outputDir = Directory('/path/to/files');
final server = HttpTransferServer(
  port: 8080,
  outputDirectory: outputDir,
  maxFileSizeMb: 100.0,
  deviceName: 'My Device',
  translations: {
    'description': 'Dosyalarınızı aktarın',
    'upload_music': 'Müzik Yükle',
    'dragAndDropDescription': 'Dosyaları sürükleyip bırakın',
    'uploading': 'Yükleniyor...',
  },
);

// Sunucuyu başlat
await server.start();

// Yerel IP'yi al
final ip = await server.getLocalIp();
print('Sunucu çalışıyor: http://$ip:8080');

// Sunucuyu durdur
await server.stop();
```

## API Endpoints

- `GET /` - Web arayüzü
- `GET /list` - Dosya listesi (JSON)
- `POST /upload` - Dosya yükle (multipart/form-data)
- `GET /download?path=xxx` - Dosya indir
- `GET /remove?path=xxx` - Dosya sil

## Dosya İşlemleri

```dart
// Dizini tara ve dosyaları yükle
await server.scanDirectory();

// Dosya listesini al
final files = server.files;

// Dosya ekle
server.addFile(FileItem(
  path: '/path/to/file.mp3',
  title: 'My Song',
  size: 1024000,
  type: 'audio',
));

// Dosya kaldır
server.removeFile('/path/to/file.mp3');
```

## Desteklenen Dosya Türleri

### Ses Dosyaları
- MP3, WAV, FLAC, AAC, OGG, M4A, WMA

### Video Dosyaları  
- MP4, AVI, MOV, MKV, FLV, WMV, WEBM

## Web Arayüzü

Sunucu otomatik olarak bir web arayüzü sunar. Tarayıcıdan `http://ip:port` adresine giderek:

- Dosyaları görüntüleyebilirsiniz
- Sürükle-bırak ile dosya yükleyebilirsiniz  
- Dosyaları indirebilirsiniz
- Dosyaları silebilirsiniz

## Özelleştirme

### Çeviriler

```dart
final translations = {
  'description': 'Transfer your files easily',
  'upload_music': 'Upload Music', 
  'dragAndDropDescription': 'Drag and drop files here',
  'uploading': 'Uploading...',
};
```

### Maksimum Dosya Boyutu

```dart
final server = HttpTransferServer(
  maxFileSizeMb: 200.0, // 200 MB limit
  // ...
);
```

## Tam Örnek

Detaylı kullanım örneği için `example/main.dart` dosyasına bakın.
