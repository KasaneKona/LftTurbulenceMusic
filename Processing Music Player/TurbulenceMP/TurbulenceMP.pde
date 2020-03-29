boolean enableHidden = false;
boolean record = false;
boolean enableFX = true;
int outputRate = 28000;
int isolateChannel = -1;
boolean warpSpeed = false;
float finishDelay = 4;

Song song;
TurbulencePlayer player;
NativeSoundPlayer nsp;

void setup() {
  size(256,256);
  textAlign(LEFT, TOP);
  BufferedReader songReader = createReader(enableHidden ? "hiddenpart.song" : "turbulence.song");
  try {
    song = parseSong(songReader);
  } catch(IOException e) {
    println("Failed to parse song");
    exit();
    return;
  }
  player = new TurbulencePlayer();
  player.play(song);
  if(isolateChannel >= 0) {
    for(int i = 0; i < 8; i++) player.channelMute[i] = (isolateChannel != i);
  }
  player.enableFX = enableFX;
  File recfile = null;
  if(record) {
    String recFn = "turbulence";
    if(enableHidden) recFn += "_hidden";
    if(!enableFX) recFn += "_nofx";
    if(isolateChannel >= 0) recFn += "_ch"+isolateChannel;
    recFn += ".wav";
    recfile = new File(sketchPath(recFn));
  }
  nsp = new NativeSoundPlayer(player, outputRate, recfile, warpSpeed ? 4 : 1, finishDelay);
  nsp.debug = true;
  nsp.open();
}

void draw() {
  background(0);
  stroke(255);
  textSize(16);
  text("SL "+player.currentSongLine, 0, 0);
  text("TL "+player.currentTrackLine, 0, 16);
  for(int c = 0; c < 8; c++) {
    text(player.c_fm_volume[c], 0, 40 + c*16);
  }
  if(nsp.finished) exit();
}

void exit() {
  if(nsp != null) nsp.close();
  super.exit();
}
