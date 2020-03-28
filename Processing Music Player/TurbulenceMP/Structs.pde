class Song {
  String name = null;
  SongLine[] lines = new SongLine[MAXSLEN];
  Track[] tracks = new Track[MAXTRACK];
  Instrument[] instruments = new Instrument[MAXINSTR];
  int length = 0;
  int usedTracks = 0;
  int usedInstruments = 0;
  public Song() {
    for(int i = 0; i < MAXSLEN; i++) lines[i] = new SongLine();
    for(int i = 0; i < MAXTRACK; i++) tracks[i] = new Track();
    for(int i = 0; i < MAXINSTR; i++) instruments[i] = new Instrument();
  }
  public String toString() {
    String build = "Song: "+name;
    build += "\nSong data:";
    for(int s = 0; s < length; s++) {
      build += "\n  "+hex(s,2)+":";
      for(int c = 0; c < 8; c++) {
        build += " " + hex(lines[s].track[c], 2);
        int transp = lines[s].transpose[c];
        build += (transp<0?"-":"+") + hex(transp, 2);
      }
    }
    return build;
  }
}

class SongLine {
  int[] track = new int[8];
  int[] transpose = new int[8];
}


class Track {
  TrackLine[] lines = new TrackLine[TRACKLEN];
  public Track() {
    for(int i = 0; i < TRACKLEN; i++) lines[i] = new TrackLine();
  }
}

class TrackLine {
  int trackNote = 0;
  int instrument = 0;
}

class Instrument {
  InstrumentLine[] lines = new InstrumentLine[MAXILEN];
  int length = 0;
  public Instrument() {
    for(int i = 0; i < MAXILEN; i++) lines[i] = new InstrumentLine();
  }
}

class InstrumentLine {
  int command = 0;
  int parameter = 0;
}
