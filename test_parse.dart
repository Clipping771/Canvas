void main() {
  try {
    print(int.parse("0xFF000000"));
  } catch(e) {
    print("Error: $e");
  }
}
