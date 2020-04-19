part of k;

void instantiateAudioService() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

class PlaylistManager {
  List<spotify.Track> _tracks;
  Completer _initiated = Completer<bool>();

  Future<List<spotify.Track>> get tracks async {
    await _initiated.future;
    return _tracks;
  }

  Future<List<String>> get mediaItem async {
    await _initiated.future;
    return _tracks
        .map((e) => jsonEncode({
              "id": e.id,
              "title": e.name,
              "album": e?.album?.name,
              "artist": e?.artists?.map((e) => e.name)?.join(", "),
              "artUri": e?.album?.images == null
                  ? ""
                  : _selectMediaItemImage(e.album.images),
              "duration": e.durationMs
            }))
        .toList();
  }

  PlaylistManager.fromTrack(spotify.Track track) {
    _tracks = [track];
    spotifyApi.recommendation.get([track.id]).then((t) async {
      var _t = await this._convertTrackSimple(t.toList());
      _tracks.addAll(_t);
      _initiated.complete(true);
    });
  }

  PlaylistManager.fromPlaylist(String id) {
    spotifyApi.playlists.getTracksByPlaylistId(id).all().then((t) {
      _tracks = t.toList();
      _initiated.complete(true);
    });
  }

  PlaylistManager.fromAlbum(String id) {
    _tracks = <spotify.Track>[];
    spotifyApi.albums.getTracks(id).all().then((t) async {
      var _t = await _convertTrackSimple(t.toList());
      _tracks.addAll(_t);
      _initiated.complete(true);
    });
  }

  PlaylistManager.artistTopTrack(String id) {
    spotifyApi.artists.getTopTracks(id, "US").then((t) {
      _tracks = t.toList();
      _initiated.complete(true);
    });
  }

  PlaylistManager.onlyTrack(spotify.Track track) {
    _tracks = [track];
    _initiated.complete(true);
  }

  Future<List<spotify.Track>> _convertTrackSimple(
      List<spotify.TrackSimple> tracks) async {
    var ids = tracks.map<String>((e) => e.id).toList();

    //splits ids into groups of 50
    var chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 50) {
      if ((i + 50) < ids.length)
        chunks.add(ids.sublist(i, i + 50));
      else
        chunks.add(ids.sublist(i));
    }

    var ret = <spotify.Track>[];
    for (var _ids in chunks) {
      ret.addAll(await spotifyApi.tracks.list(_ids));
    }

    return ret;
  }

  String _selectMediaItemImage(List<spotify.Image> images) {
    if (images.length == 0)
      return null;
    else if (images.length == 1)
      return images.first.url;
    else {
      //find the smallest image
      var url = "";
      var lurl = "";
      var w = 1000000, h = 1000000;
      images.forEach((element) {
        if (element.width < w && element.height < h) {
          w = element.width;
          h = element.height;
          lurl = url;
          url = element.url;
        }
      });

      if (lurl != "") return lurl;

      return url;
    }
  }

  initQueue() async {
    var json = await mediaItem;
    AudioService.customAction("initQueue", json);
  }

  initAudioService() async {
    await AudioService.start(
      backgroundTaskEntrypoint: instantiateAudioService,
      androidNotificationChannelName: 'Audio Service Demo',
      notificationColor: 0xFF2196f3,
      androidNotificationIcon: 'mipmap/ic_launcher',
      enableQueue: true,
    );
    initQueue();
  }
}