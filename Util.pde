int sign8(int v) {
  return (byte)v;
}
int[] initFreqTable(int outputRate) {
  int[] freqbase = {
    0x1322, 0x1446, 0x157a, 0x16c1,
    0x181c, 0x198b, 0x1b0f, 0x1cab,
    0x1e60, 0x202e, 0x2218, 0x241f};
  int count = 94;
  int[] table = new int[count];
  int src = 0;
  int octave = 7;
  int addr = 0;
  while(count > 0) {
    int read = freqbase[src++];
    read >>>= octave;
    table[addr++] = read;//* outputRate / SAMPLEFREQ;
    if(src >= 12) {
      src -= 12;
      octave--;
    }
    count--;
  }
  return table;
}
