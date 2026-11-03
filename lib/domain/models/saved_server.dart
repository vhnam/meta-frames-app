/// An API server kept in Settings so the app can switch to it again.
class SavedServer {
  const SavedServer({required this.name, required this.url});

  SavedServer.fromJson(Map<String, dynamic> j)
    : name = j['name'],
      url = j['url'];

  final String name, url;

  Map<String, Object?> toJson() => {'name': name, 'url': url};
}
