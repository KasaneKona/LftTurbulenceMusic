class TurbulencePlayer {
  Song s;
  int currentSongLine;
  boolean restarting;
  int currentTrackLine;
  float frameTimer;
  float framesPerSample;
  int songTimer;
  boolean finished;
  int[] freqTable;
  int[] c_track = new int[8];
  int[] c_transp = new int[8];
  int[] c_tnote = new int[8];
  int[] c_inote = new int[8];
  int[] c_instr = new int[8];
  int[] c_instr_l = new int[8];
  int[] c_lasti = new int[8];
  int[] c_phase = new int[8];
  int[] c_freq = new int[8];
  int[] c_slide = new int[8];
  int[] c_vrate = new int[8];
  int[] c_vdepth = new int[8];
  int[] c_vpos = new int[8];
  int[] c_fade = new int[8];
  int[] c_sweep = new int[8];
  int[] c_fm_amount = new int[8];
  int[] c_fm_multiplier = new int[8];
  int[] c_fm_volume = new int[8];
  int[] c_timer = new int[8];
  int[] reverbBuffer;
  int reverb_1 = 0;
  int reverb_2 = 0;
  int reverb_3 = 250;
  boolean enableFX = true;
  boolean[] channelMute = new boolean[8];
  
  public TurbulencePlayer() {
    freqTable = initFreqTable();
    framesPerSample = 60f / SAMPLEFREQ;
    reverbBuffer = new int[256];
  }
  public void play(Song s) {
    this.s = s;
    currentSongLine = -1;
    restarting = false;
    currentTrackLine = TRACKLEN-1;
    songTimer = 0;
    finished = false;
  }
  void step() {
    if(finished) return;
    currentTrackLine++;
    if(currentTrackLine >= TRACKLEN) {
      currentTrackLine = 0;
      if(restarting) {
        currentSongLine = 0;
        restarting = false;
      } else currentSongLine++;
      if(currentSongLine >= s.length) {
        finished = true;
        return;
      }
      for(int c = 0; c < 8; c++) {
        c_track[c] = s.lines[currentSongLine].track[c];
        c_transp[c] = s.lines[currentSongLine].transpose[c];
        if(c_track[c] == 0 && c_transp[c] != 0) {
          finished = true;
          return;
        }
      }
    }
    
    for(int c = 0; c < 8; c++) {
      int newNote = s.tracks[c_track[c]].lines[currentTrackLine].trackNote;
      int newInstrument = s.tracks[c_track[c]].lines[currentTrackLine].instrument;
      if(newInstrument > 0) {
        goToInstrument(c, newInstrument);
        c_timer[c] = 0;
        c_lasti[c] = newInstrument;
      }
      if(newNote > 0) {
        newNote--; // actually happens during packing
        c_fm_volume[c] = 0;
        int inum = c_transp[c];
        newNote += inum;
        newNote &= 255;
        c_inote[c] = newNote << 8;
        // Write long 0 to timer actually clears slide, fade and sweep too
        c_timer[c] = 0;
        c_slide[c] = 0;
        c_fade[c] = 0;
        c_sweep[c] = 0;
        c_tnote[c] = newNote;
        c_vrate[c] = 24;
        c_vdepth[c] = 0; // Overwritten as part of a tricky long write like above
        goToInstrument(c, c_lasti[c]);
      }
    }
  }
  void frame() {
    songTimer--;
    if(songTimer <= 0) {
      step();
      songTimer = TEMPO;
    }
    for(int c = 0; c < 8; c++) {
      while(true) {
        if(c_instr[c] == 0) break;
        if(c_timer[c] > 0) {
          c_timer[c]--;
          break;
        }
        int cc = s.instruments[c_instr[c]].lines[c_instr_l[c]].command;
        int cp = s.instruments[c_instr[c]].lines[c_instr_l[c]].parameter;
        c_instr_l[c]++;
        executeCommand(c, cc, cp);
        if(c_instr_l[c] >= s.instruments[c_instr[c]].length) {
          goToInstrument(c, 0);
          break;
        }
      }
      int slide = c_slide[c] << 3;
      int nfreq = c_inote[c];
      nfreq += slide;
      if((nfreq&0x8000) > 0) nfreq = 0;
      c_inote[c] = nfreq;
      int vrate = c_vrate[c];
      int vpos = c_vpos[c];
      vrate += vpos;
      c_vpos[c] = vrate;
      vpos <<= 5;
      int mulux = isin(vpos);
      boolean z = mulux>=0;
      mulux = abs(mulux);
      // need renames
      int mulus = c_vdepth[c];
      mulus &= 0xFF;
      mulus *= mulux;
      if(!z) mulus = -mulus;
      mulus >>= 13;
      nfreq += mulus;
      int freqTablePointer = (nfreq >>> 8) & 0xFF;
      //hackfix
      if(freqTablePointer >= freqTable.length-1) freqTablePointer = freqTable.length - 2;
      int freq = freqTable[freqTablePointer];
      mulux = freqTable[freqTablePointer+1] - freq;
      nfreq &= 0xFF;
      mulux *= nfreq;
      mulux >>>= 8;
      freq += mulux;
      int fmAmt = c_fm_amount[c];
      fmAmt += c_sweep[c];
      if(fmAmt < 0) fmAmt = 0;
      if(fmAmt > 255) {
        fmAmt = 255;
        c_sweep[c] = -c_sweep[c];
      }
      c_fm_amount[c] = fmAmt;
      int fade = c_fade[c];
      int fmVol = c_fm_volume[c];
      fmVol += fade;
      if(fmVol < 0) fmVol = 0;
      if(fmVol > 255) fmVol = 255;
      c_fm_volume[c] = fmVol;
      c_freq[c] = freq;
    }
  }
  short[] getSample() {
    frameTimer += framesPerSample;
    while(frameTimer >= 1) {
      frameTimer--;
      frame();
    }
    int samp = 0;
    for(int i = 0; i < 8; i++) {
      if(channelMute[i]) continue;
      samp += getWave(i);
    }
    //samp += samp>>1;
    if(enableFX) {
      samp <<= 4;
      // Reverb stereo spatialization
      int right = reverbBuffer[reverb_1];
      int left = right;
      left &= 0xFFFF0000;
      left >>= 1;
      right <<= 16;
      right >>= 1;
      left += samp;
      right += samp;
      int reverbFeedback = left;
      reverbFeedback >>= 16;
      reverbBuffer[reverb_2] = reverbFeedback;
      reverbFeedback = right;
      reverbFeedback &= 0xFFFF0000;
      reverbBuffer[reverb_3] += reverbFeedback;
      reverb_1 = (reverb_1+1) & 255;
      reverb_2 = (reverb_2+1) & 255;
      reverb_3 = (reverb_3+1) & 255;
      // Stereo widening
      int diff = right - left;
      right >>= 2;
      left >>= 2;
      right += left;
      left = right;
      diff <<= 1;
      right += diff;
      left -= diff;
      return new short[] {(short)(left>>16), (short)(right>>16)};
    }
    samp >>= 12;
    return new short[] {(short)samp, (short)samp};
  }
  int getWave(int ch) {
    int volume = c_fm_volume[ch];
    int freq = c_freq[ch];
    int amount = c_fm_amount[ch];
    int multiplier = c_fm_multiplier[ch];
    freq <<= 16;
    c_phase[ch] += freq;
    int phase = c_phase[ch];
    int mulux = phase >>> 16;
    multiplier *= mulux;
    multiplier >>>= 5;
    boolean c = (multiplier&0x0800) > 0;
    boolean z = (multiplier&0x1000) == 0;
    multiplier &= 0x07FF;
    if(c) multiplier ^= 0x07FF;
    int sinmult = isin(multiplier);
    int mod = amount * sinmult;
    mod <<= 10;
    if(!z) mod = -mod;
    mod += phase;
    //mod = phase;
    mod >>= 19;
    c = (mod&0x0800) > 0;
    z = (mod&0x1000) == 0;
    mod &= 0x07FF;
    if(c) mod ^= 0x7FF;
    int sinmod = isin(mod);
    sinmod *= volume & 255;
    if(!z) sinmod = -sinmod;
    return sinmod;
  }
  int isin(int a) {
    // TODO REPLACE WITH TABLE
    return round(65535 * sin(a * TWO_PI / 8192));
  }
  void executeCommand(int ch, int cmd, int param) {
    switch(cmd) {
      case 0: goToInstrument(ch, 0); break; // Test
      case 1: goToInstrument(ch, param); break;
      case 3: c_slide[ch] = sign8(param); break;
      case 4: c_vrate[ch] = param; break;
      case 5: c_vdepth[ch] = param; break;
      case 6: c_fm_volume[ch] = param; break;
      case 7: c_fade[ch] = sign8(param); break;
      case 8: c_fm_amount[ch] = param; break;
      case 9: restarting = true; break;
      case 10:
        c_inote[ch] &= 0xFF;
        c_inote[ch] |= (c_tnote[ch] + sign8(param))<<8; break;
      case 11: c_fm_multiplier[ch] = param; break;
      case 12: c_sweep[ch] = sign8(param); break;
      case 13: c_timer[ch] = param; break;
      default:
        println("Illegal command in instrument "+c_instr[ch]+": "+cmd+"("+param+")");
    }
  }
  void goToInstrument(int ch, int instr) {
    c_instr[ch] = instr;
    c_instr_l[ch] = 0;
    // TODO: FIX
  }
}
