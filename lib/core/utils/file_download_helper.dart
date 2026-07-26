import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';

void downloadReportFile(String filename, String content, String mimeType) {
  downloadFileImpl(filename, content, mimeType);
}
