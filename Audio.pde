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
  public NativeSoundPlayer(TurbulencePlayer music, int sampleRate, File recFile, float outSpeedMult) {
    this.music = music;
    recordFile=recFile;
    if(recordFile != null) doRecord = true;
    extBufSamples = sampleRate / 10; // 100ms/6frame buffer
    intBufSamples = sampleRate / 20; // 50ms/3frame chunk size
    internalBuffer=new byte[intBufSamples * 2 * 2];
    try {
      format = new AudioFormat((float)sampleRate * outSpeedMult, 8 * 2, 2, true, false);
      formatRecord = new AudioFormat((float)sampleRate, 8 * 2, 2, true, false);
      line = (SourceDataLine) AudioSystem.getSourceDataLine(format);
      line.open(format, extBufSamples * 2 * 2);
    } 
    catch(LineUnavailableException e) {
      println("Couldn't get audio output!");
      finished = true;
      return;
    }
  }
  public void open() {
    if (finished) return;
    if (doRecord) {
      recordBuffer = new ByteArrayOutputStream();
      println("Beginning soundtrack recording");
    }
    start();
    if (debug) println("Audio output started");
  }
  public void close() {
    if (finished) return;
    finished=true;
    if (recordFile!=null) {
      println("Saving soundtrack recording...");
      ByteArrayInputStream b_in = new ByteArrayInputStream(recordBuffer.toByteArray());
      AudioInputStream ais = new AudioInputStream(b_in, formatRecord, recordBuffer.size());
      try {
        AudioSystem.write(ais, AudioFileFormat.Type.WAVE, recordFile);
      }
      catch(IOException e) {
        println("Couldn't write to file " + recordFile.getAbsolutePath());
      }
    }
    if (debug) println("Audio output finished");
  }
  public void run() {
    if (finished) return;
    line.start();
    while (!finished) {
      int offset = 0;
      // Generate sample buffer
      for (int i = 0; i < intBufSamples; i++) {
        short[] samples = music.getSample();
        short sampleL = samples[0];
        short sampleR = samples[1];
        internalBuffer[offset++] = (byte)(sampleL >> 0);
        internalBuffer[offset++] = (byte)(sampleL >> 8);
        internalBuffer[offset++] = (byte)(sampleR >> 0);
        internalBuffer[offset++] = (byte)(sampleR >> 8);
      }
      // Copy internal buffer to record buffer
      if (doRecord) {
        recordBuffer.write(internalBuffer, 0, internalBuffer.length);
      }
      // Wait for space to become available
      while (line.available() < intBufSamples << 2) {
        try {
          Thread.sleep(1);
        }
        catch (InterruptedException nom) {
        }
      }
      line.write(internalBuffer, 0, internalBuffer.length);
    }
    line.flush();
    line.stop();
    line.close();
    line = null;
  }
  public boolean musicFinished() {
    return music.finished;
  }
}
