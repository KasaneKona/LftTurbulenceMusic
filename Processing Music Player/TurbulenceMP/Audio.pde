import javax.sound.sampled.*;
import java.util.Arrays;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.nio.FloatBuffer;
import java.nio.ByteBuffer;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;

public class NativeSoundPlayer extends Thread {
  boolean debug = false;
  private TurbulencePlayer music;
  short[] currSamples;
  float sampleTimer;
  int outputRate;
  float relativeSampleRate;
  private SourceDataLine line;
  private boolean finished=false;
  private byte[] internalBuffer;
  private int intBufSamples;
  private int extBufSamples;
  private AudioFormat format;
  private AudioFormat formatRecord;
  private ByteArrayOutputStream recordBuffer;
  private File recordFile;
  private boolean doRecord=false;
  float finishDelay;
  float finishCountdown;
  public NativeSoundPlayer(TurbulencePlayer music, int outputRate, File recFile, float outSpeedMult, float finishDelay) {
    this.outputRate = outputRate;
    relativeSampleRate = (float)SAMPLEFREQ / outputRate;
    this.music = music;
    this.finishDelay = finishDelay;
    recordFile = recFile;
    if(recordFile != null) doRecord = true;
    extBufSamples = outputRate / 10; // 100ms/6frame buffer
    intBufSamples = outputRate / 20; // 50ms/3frame chunk size
    internalBuffer=new byte[intBufSamples * 2 * 2];
    try {
      format = new AudioFormat((float)outputRate * outSpeedMult, 8 * 2, 2, true, false);
      formatRecord = new AudioFormat((float)outputRate, 8 * 2, 2, true, false);
      line = (SourceDataLine) AudioSystem.getSourceDataLine(format);
      line.open(format, extBufSamples * 2 * 2);
    } catch(LineUnavailableException e) {
      println("Couldn't get audio output!");
      finished = true;
      return;
    }
  }
  public void open() {
    if(finished) return;
    if(doRecord) {
      recordBuffer = new ByteArrayOutputStream();
      println("Beginning soundtrack recording");
    }
    start();
    if(debug) println("Audio output started");
  }
  public void close() {
    if(finished) return;
    if(recordFile != null) {
      println("Saving soundtrack recording...");
      try {
        recordBuffer.close(); // Apparently does nothing
        ByteArrayInputStream b_in = new ByteArrayInputStream(recordBuffer.toByteArray());
        AudioInputStream ais = new AudioInputStream(b_in, formatRecord, recordBuffer.size());
        AudioSystem.write(ais, AudioFileFormat.Type.WAVE, recordFile);
        ais.close();
      } catch(IOException e) {
        println("Couldn't write to file " + recordFile.getAbsolutePath());
      }
    }
    if(debug) println("Audio output finished");
    finished = true;
  }
  public void run() {
    if(finished) return;
    finishCountdown = finishDelay;
    currSamples = new short[2];
    line.start();
    while(!finished) {
      int offset = 0;
      // Generate sample buffer
      for(int i = 0; i < intBufSamples; i++) {
        short[] outSamples = doSample();
        short sampleL = outSamples[0];
        short sampleR = outSamples[1];
        internalBuffer[offset++] = (byte)(sampleL >> 0);
        internalBuffer[offset++] = (byte)(sampleL >> 8);
        internalBuffer[offset++] = (byte)(sampleR >> 0);
        internalBuffer[offset++] = (byte)(sampleR >> 8);
      }
      // Copy internal buffer to record buffer
      if(doRecord) {
        recordBuffer.write(internalBuffer, 0, internalBuffer.length);
      }
      // Wait for space to become available
      while(line.available() < intBufSamples << 2) {
        try {
          Thread.sleep(1);
        } catch(InterruptedException nom) {
        }
      }
      line.write(internalBuffer, 0, internalBuffer.length);
      if(musicFinished()) {
        finishCountdown -= (float)intBufSamples / outputRate;
        if(finishCountdown <= 0) break;
      }
    }
    line.flush();
    line.stop();
    line.close();
    line = null;
    this.close();
  }
  public boolean musicFinished() {
    return music.finished;
  }
  short[] doSample() {
    float sampleTimerLast = sampleTimer;
    sampleTimer += relativeSampleRate;
    float antiAliasL = currSamples[0];
    float antiAliasR = currSamples[1];
    if (sampleTimer >= 1) {
      float remaining = 1 - sampleTimerLast;
      float totalSamples = remaining;
      antiAliasL = currSamples[0] * remaining;
      antiAliasR = currSamples[1] * remaining;
      for(int i = 1; i <= sampleTimer - 1; i++) {
        short[] intermediate = music.getSample();
        antiAliasL += intermediate[0];
        antiAliasR += intermediate[1];
        totalSamples++;
      }
      sampleTimer -= floor(sampleTimer);
      currSamples = music.getSample();
      antiAliasL += currSamples[0] * sampleTimer;
      antiAliasR += currSamples[1] * sampleTimer;
      totalSamples += sampleTimer;
      antiAliasL /= totalSamples;
      antiAliasR /= totalSamples;
    }
    return new short[] {(short)round(antiAliasL), (short)round(antiAliasR)};
  }
}
