class StreamUri {
  const StreamUri(this.uri, {this.headers = const {}});

  final Uri uri;
  final Map<String, String> headers;
}
