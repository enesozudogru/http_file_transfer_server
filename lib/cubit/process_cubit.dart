import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http_file_transfer_server/http_transfer_server.dart';

class ProcessCubit extends Cubit<List<FileItem>> {
  ProcessCubit() : super([]);

  void addFile(FileItem file) {
    final updatedList = List<FileItem>.from(state)..add(file);
    emit(updatedList);
  }

  void removeFile(String path) {
    final updatedList = state.where((file) => file.path != path).toList();
    emit(updatedList);
  }

  void clearFiles() {
    emit([]);
  }

  void setFiles(List<FileItem> files) {
    emit(files);
  }
}
