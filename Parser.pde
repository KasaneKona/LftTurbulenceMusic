Song parseSong(BufferedReader input) throws IOException {
  Song s = new Song();
  String strLine;
  while((strLine = input.readLine()) != null) {
    if(strLine.trim().length() == 0) continue; // Blank line
    if(strLine.startsWith("se ")) { // Song line
      String[] vals = strLine.substring(3).split(" ");
      try {
        int l = unhex(vals[0])&255;
        int c = unhex(vals[1])&255;
        int t = unhex(vals[2])&255;
        int x = unhex(vals[3])&255;
        s.lines[l].track[c] = t;
        s.lines[l].transpose[c] = sign8(x);
        if(l >= s.length) s.length = l + 1;
      } catch(Exception e) {
        println("Error parsing song line "+strLine);
      }
    } else if(strLine.startsWith("tl ")) { // Track line
      String[] vals = strLine.substring(3).split(" ");
      try {
        int t = unhex(vals[0]);
        int l = unhex(vals[1]);
        int n = unhex(vals[2]);
        int i = unhex(vals[3]);
        s.tracks[t].lines[l].trackNote = n;
        s.tracks[t].lines[l].instrument = i;
        if(t >= s.usedTracks) s.usedTracks = t + 1;
      } catch(Exception e) {
        println("Error parsing track line "+strLine);
      }
    } else if(strLine.startsWith("il ")) { // Instrument line
      String[] vals = strLine.substring(3).split(" ");
      try {
        int i = unhex(vals[0]);
        int l = unhex(vals[1]);
        int c = unhex(vals[2]);
        int cc = c>>>8;
        int cp = c&255;
        s.instruments[i].lines[l].command = cc;
        s.instruments[i].lines[l].parameter = cp;
        if(l >= s.instruments[i].length) s.instruments[i].length = l + 1;
        if(i >= s.usedInstruments) s.usedInstruments = i + 1;
      } catch(Exception e) {
        throw e;
      }
    } else { // Name or comment
      if(s.name == null) s.name = strLine;
    }
  }
  return s;
}
