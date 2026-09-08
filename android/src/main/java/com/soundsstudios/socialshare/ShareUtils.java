package com.soundsstudios.socialshare;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.net.Uri;
import android.util.Base64;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.List;

/**
 * Android video composition helpers for SocialShare (image + audio + overlays).
 */
public final class ShareUtils {
    private static final String TAG = "SocialShareUtils";
    private static final int WIDTH = 1080;
    private static final int HEIGHT = 1920;
    private static final int FRAME_RATE = 30;
    private static final int VIDEO_BIT_RATE = 8_000_000;
    private static final int AUDIO_BIT_RATE = 192_000;
    private static final int AUDIO_SAMPLE_RATE = 44100;
    private static final int AUDIO_CHANNEL_COUNT = 2;
    private static final long TIMEOUT_US = 10_000;

    private ShareUtils() {}

    public static File resolveLocalFile(String pathOrUri) {
        if (pathOrUri == null || pathOrUri.isEmpty()) {
            return null;
        }
        try {
            Uri uri = Uri.parse(pathOrUri);
            String scheme = uri.getScheme();
            if (scheme == null) {
                File file = new File(pathOrUri);
                return file.exists() ? file : null;
            }
            if ("file".equalsIgnoreCase(scheme)) {
                String path = uri.getPath();
                if (path == null) {
                    return null;
                }
                File file = new File(path);
                return file.exists() ? file : null;
            }
            // Unsupported content:// without resolver copy — caller should pass file://
            File asPath = new File(pathOrUri);
            return asPath.exists() ? asPath : null;
        } catch (Exception e) {
            Log.e(TAG, "Failed to resolve file: " + pathOrUri, e);
            return null;
        }
    }

    public interface VideoCallback {
        void onComplete(boolean success, File outputFile, String error);
    }

    public static void createVideoFromImageAndAudioAsync(
            Context context,
            File imageFile,
            File audioFile,
            double startTimeSec,
            Double durationSec,
            JSONArray textOverlays,
            JSONArray imageOverlays,
            JSONArray timeBasedTextOverlays,
            VideoCallback callback
    ) {
        new Thread(() -> {
            File outputDir = new File(context.getCacheDir(), "videos");
            if (!outputDir.exists() && !outputDir.mkdirs()) {
                callback.onComplete(false, null, "Failed to create video cache directory");
                return;
            }
            File outputFile = new File(outputDir, "share_video_" + System.currentTimeMillis() + ".mp4");
            try {
                createVideoFromImageAndAudio(
                        imageFile,
                        audioFile,
                        outputFile,
                        startTimeSec,
                        durationSec,
                        textOverlays,
                        imageOverlays,
                        timeBasedTextOverlays
                );
                callback.onComplete(true, outputFile, null);
            } catch (Exception e) {
                Log.e(TAG, "Video creation failed", e);
                if (outputFile.exists()) {
                    //noinspection ResultOfMethodCallIgnored
                    outputFile.delete();
                }
                callback.onComplete(false, null, e.getMessage());
            }
        }, "social-share-video").start();
    }

    public static void createVideoFromImageAndAudio(
            File imageFile,
            File audioFile,
            File outputFile,
            double startTimeSec,
            Double durationSec,
            JSONArray textOverlays,
            JSONArray imageOverlays,
            JSONArray timeBasedTextOverlays
    ) throws IOException {
        Bitmap background = decodeBackground(imageFile);
        if (background == null) {
            throw new IOException("Unable to decode background image");
        }

        PcmAudio pcm = decodeAudioToPcm(audioFile, startTimeSec, durationSec);
        double videoDurationSec = pcm.durationSec;
        if (videoDurationSec <= 0.05) {
            throw new IOException("Audio duration too short after trim");
        }

        List<OverlayText> staticTexts = parseTextOverlays(textOverlays);
        List<OverlayImage> images = parseImageOverlays(imageOverlays);
        List<OverlayText> timedTexts = parseTextOverlays(timeBasedTextOverlays);

        boolean hasTimed = !timedTexts.isEmpty() || hasTimedImages(images);
        int frameRate = hasTimed ? FRAME_RATE : 10;
        int frameCount = Math.max(1, (int) Math.ceil(videoDurationSec * frameRate));

        if (outputFile.exists()) {
            //noinspection ResultOfMethodCallIgnored
            outputFile.delete();
        }

        MediaMuxer muxer = new MediaMuxer(outputFile.getAbsolutePath(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
        MediaCodec videoEncoder = null;
        MediaCodec audioEncoder = null;
        boolean muxerStarted = false;
        int videoTrack = -1;
        int audioTrack = -1;

        try {
            videoEncoder = createVideoEncoder();
            audioEncoder = createAudioEncoder();
            videoEncoder.start();
            audioEncoder.start();

            MediaCodec.BufferInfo videoInfo = new MediaCodec.BufferInfo();
            MediaCodec.BufferInfo audioInfo = new MediaCodec.BufferInfo();

            int audioSamplesFed = 0;
            boolean audioInputDone = false;
            boolean audioOutputDone = false;
            boolean videoInputDone = false;
            boolean videoOutputDone = false;
            int framesQueued = 0;

            byte[] yuv = new byte[WIDTH * HEIGHT * 3 / 2];
            Canvas canvas = new Canvas();
            Bitmap frameBitmap = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888);
            canvas.setBitmap(frameBitmap);
            int[] argb = new int[WIDTH * HEIGHT];

            while (!videoOutputDone || !audioOutputDone) {
                if (!videoInputDone) {
                    int inIndex = videoEncoder.dequeueInputBuffer(TIMEOUT_US);
                    if (inIndex >= 0) {
                        if (framesQueued >= frameCount) {
                            videoEncoder.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                            videoInputDone = true;
                        } else {
                            double timeSec = framesQueued / (double) frameRate;
                            drawFrame(canvas, background, staticTexts, timedTexts, images, timeSec);
                            frameBitmap.getPixels(argb, 0, WIDTH, 0, 0, WIDTH, HEIGHT);
                            encodeYUV420SP(yuv, argb, WIDTH, HEIGHT);
                            ByteBuffer input = videoEncoder.getInputBuffer(inIndex);
                            if (input != null) {
                                input.clear();
                                input.put(yuv);
                            }
                            long ptsUs = (framesQueued * 1_000_000L) / frameRate;
                            videoEncoder.queueInputBuffer(inIndex, 0, yuv.length, ptsUs, 0);
                            framesQueued++;
                        }
                    }
                }

                if (!audioInputDone) {
                    int inIndex = audioEncoder.dequeueInputBuffer(TIMEOUT_US);
                    if (inIndex >= 0) {
                        ByteBuffer input = audioEncoder.getInputBuffer(inIndex);
                        if (input == null) {
                            audioEncoder.queueInputBuffer(inIndex, 0, 0, 0, 0);
                        } else {
                            input.clear();
                            int maxSamples = input.capacity() / 2;
                            int remaining = pcm.samples.length - audioSamplesFed;
                            if (remaining <= 0) {
                                audioEncoder.queueInputBuffer(inIndex, 0, 0, presentationTimeUsForSample(audioSamplesFed, pcm.sampleRate, pcm.channelCount), MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                                audioInputDone = true;
                            } else {
                                int toWrite = Math.min(maxSamples, remaining);
                                for (int i = 0; i < toWrite; i++) {
                                    input.putShort(pcm.samples[audioSamplesFed + i]);
                                }
                                long pts = presentationTimeUsForSample(audioSamplesFed, pcm.sampleRate, pcm.channelCount);
                                audioEncoder.queueInputBuffer(inIndex, 0, toWrite * 2, pts, 0);
                                audioSamplesFed += toWrite;
                            }
                        }
                    }
                }

                if (!videoOutputDone) {
                    int outIndex = videoEncoder.dequeueOutputBuffer(videoInfo, TIMEOUT_US);
                    if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        if (videoTrack >= 0) {
                            throw new IOException("Video format changed twice");
                        }
                        videoTrack = muxer.addTrack(videoEncoder.getOutputFormat());
                        if (audioTrack >= 0 && !muxerStarted) {
                            muxer.start();
                            muxerStarted = true;
                        }
                    } else if (outIndex >= 0) {
                        if ((videoInfo.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
                            videoInfo.size = 0;
                        }
                        if (videoInfo.size > 0) {
                            if (!muxerStarted) {
                                if (videoTrack < 0 || audioTrack < 0) {
                                    videoEncoder.releaseOutputBuffer(outIndex, false);
                                    continue;
                                }
                                muxer.start();
                                muxerStarted = true;
                            }
                            ByteBuffer encoded = videoEncoder.getOutputBuffer(outIndex);
                            if (encoded != null) {
                                encoded.position(videoInfo.offset);
                                encoded.limit(videoInfo.offset + videoInfo.size);
                                muxer.writeSampleData(videoTrack, encoded, videoInfo);
                            }
                        }
                        videoEncoder.releaseOutputBuffer(outIndex, false);
                        if ((videoInfo.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            videoOutputDone = true;
                        }
                    }
                }

                if (!audioOutputDone) {
                    int outIndex = audioEncoder.dequeueOutputBuffer(audioInfo, TIMEOUT_US);
                    if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        if (audioTrack >= 0) {
                            throw new IOException("Audio format changed twice");
                        }
                        audioTrack = muxer.addTrack(audioEncoder.getOutputFormat());
                        if (videoTrack >= 0 && !muxerStarted) {
                            muxer.start();
                            muxerStarted = true;
                        }
                    } else if (outIndex >= 0) {
                        if ((audioInfo.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
                            audioInfo.size = 0;
                        }
                        if (audioInfo.size > 0) {
                            if (!muxerStarted) {
                                if (videoTrack < 0 || audioTrack < 0) {
                                    audioEncoder.releaseOutputBuffer(outIndex, false);
                                    continue;
                                }
                                muxer.start();
                                muxerStarted = true;
                            }
                            ByteBuffer encoded = audioEncoder.getOutputBuffer(outIndex);
                            if (encoded != null) {
                                encoded.position(audioInfo.offset);
                                encoded.limit(audioInfo.offset + audioInfo.size);
                                muxer.writeSampleData(audioTrack, encoded, audioInfo);
                            }
                        }
                        audioEncoder.releaseOutputBuffer(outIndex, false);
                        if ((audioInfo.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            audioOutputDone = true;
                        }
                    }
                }
            }
        } finally {
            if (videoEncoder != null) {
                try { videoEncoder.stop(); } catch (Exception ignored) {}
                videoEncoder.release();
            }
            if (audioEncoder != null) {
                try { audioEncoder.stop(); } catch (Exception ignored) {}
                audioEncoder.release();
            }
            try {
                if (muxerStarted) {
                    muxer.stop();
                }
            } catch (Exception ignored) {}
            muxer.release();
            background.recycle();
        }

        Log.d(TAG, "Created video: " + outputFile.getAbsolutePath() + " (" + outputFile.length() + " bytes)");
    }

    private static MediaCodec createVideoEncoder() throws IOException {
        MediaFormat format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, WIDTH, HEIGHT);
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar);
        format.setInteger(MediaFormat.KEY_BIT_RATE, VIDEO_BIT_RATE);
        format.setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE);
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1);
        MediaCodec codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC);
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
        return codec;
    }

    private static MediaCodec createAudioEncoder() throws IOException {
        MediaFormat format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, AUDIO_SAMPLE_RATE, AUDIO_CHANNEL_COUNT);
        format.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC);
        format.setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_BIT_RATE);
        format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384);
        MediaCodec codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC);
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
        return codec;
    }

    private static long presentationTimeUsForSample(int sampleIndex, int sampleRate, int channelCount) {
        int frames = sampleIndex / Math.max(1, channelCount);
        return frames * 1_000_000L / sampleRate;
    }

    private static Bitmap decodeBackground(File imageFile) {
        BitmapFactory.Options opts = new BitmapFactory.Options();
        opts.inPreferredConfig = Bitmap.Config.ARGB_8888;
        Bitmap decoded = BitmapFactory.decodeFile(imageFile.getAbsolutePath(), opts);
        if (decoded == null) {
            return null;
        }
        if (decoded.getWidth() == WIDTH && decoded.getHeight() == HEIGHT) {
            return decoded;
        }
        Bitmap scaled = Bitmap.createScaledBitmap(decoded, WIDTH, HEIGHT, true);
        if (scaled != decoded) {
            decoded.recycle();
        }
        return scaled;
    }

    private static void drawFrame(
            Canvas canvas,
            Bitmap background,
            List<OverlayText> staticTexts,
            List<OverlayText> timedTexts,
            List<OverlayImage> images,
            double timeSec
    ) {
        canvas.drawBitmap(background, 0, 0, null);
        for (OverlayImage image : images) {
            if (isVisible(image.startTime, image.endTime, timeSec) && image.bitmap != null) {
                float left = (float) ((image.x / 100.0) * WIDTH - image.drawWidth / 2f);
                float top = (float) ((image.y / 100.0) * HEIGHT - image.drawHeight / 2f);
                RectF dest = new RectF(left, top, left + image.drawWidth, top + image.drawHeight);
                canvas.drawBitmap(image.bitmap, null, dest, null);
            }
        }
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setTextAlign(Paint.Align.CENTER);
        for (OverlayText text : staticTexts) {
            if (isVisible(text.startTime, text.endTime, timeSec)) {
                drawTextOverlay(canvas, paint, text);
            }
        }
        for (OverlayText text : timedTexts) {
            if (isVisible(text.startTime, text.endTime, timeSec)) {
                drawTextOverlay(canvas, paint, text);
            }
        }
    }

    private static void drawTextOverlay(Canvas canvas, Paint paint, OverlayText text) {
        paint.setColor(text.color);
        paint.setTextSize(text.fontSize);
        paint.setFakeBoldText(text.bold);
        paint.setTextSkewX(text.italic ? -0.25f : 0f);
        paint.setTypeface(Typeface.create(Typeface.DEFAULT, text.bold ? Typeface.BOLD : Typeface.NORMAL));
        float x = (float) ((text.x / 100.0) * WIDTH);
        float y = (float) ((text.y / 100.0) * HEIGHT);
        Paint.FontMetrics fm = paint.getFontMetrics();
        float baseline = y - (fm.ascent + fm.descent) / 2f;
        if (text.shadowRadius > 0) {
            paint.setShadowLayer(text.shadowRadius, text.shadowDx, text.shadowDy, text.shadowColor);
        } else {
            paint.clearShadowLayer();
        }
        canvas.drawText(text.text, x, baseline, paint);
    }

    private static boolean isVisible(Double start, Double end, double timeSec) {
        if (start != null && timeSec < start) {
            return false;
        }
        if (end != null && timeSec > end) {
            return false;
        }
        return true;
    }

    private static boolean hasTimedImages(List<OverlayImage> images) {
        for (OverlayImage image : images) {
            if (image.startTime != null || image.endTime != null) {
                return true;
            }
        }
        return false;
    }

    private static List<OverlayText> parseTextOverlays(JSONArray array) {
        List<OverlayText> list = new ArrayList<>();
        if (array == null) {
            return list;
        }
        for (int i = 0; i < array.length(); i++) {
            JSONObject obj = array.optJSONObject(i);
            if (obj == null) {
                continue;
            }
            String text = obj.optString("text", null);
            if (text == null || text.isEmpty()) {
                continue;
            }
            OverlayText overlay = new OverlayText();
            overlay.text = text;
            overlay.x = obj.optDouble("x", 50);
            overlay.y = obj.optDouble("y", 50);
            overlay.fontSize = (float) obj.optDouble("fontSize", 48);
            overlay.color = parseColor(obj.optString("color", "#FFFFFF"));
            String weight = obj.optString("fontWeight", "normal");
            String style = obj.optString("fontStyle", "normal");
            overlay.bold = "bold".equalsIgnoreCase(weight) || "700".equals(weight);
            overlay.italic = "italic".equalsIgnoreCase(style);
            if (obj.has("startTime") && !obj.isNull("startTime")) {
                overlay.startTime = obj.optDouble("startTime");
            }
            if (obj.has("endTime") && !obj.isNull("endTime")) {
                overlay.endTime = obj.optDouble("endTime");
            }
            if (obj.has("shadowBlur")) {
                overlay.shadowRadius = (float) obj.optDouble("shadowBlur", 0);
                overlay.shadowDx = (float) obj.optDouble("shadowOffsetX", 0);
                overlay.shadowDy = (float) obj.optDouble("shadowOffsetY", 0);
                overlay.shadowColor = parseColor(obj.optString("shadowColor", "#000000"));
            }
            list.add(overlay);
        }
        return list;
    }

    private static List<OverlayImage> parseImageOverlays(JSONArray array) {
        List<OverlayImage> list = new ArrayList<>();
        if (array == null) {
            return list;
        }
        for (int i = 0; i < array.length(); i++) {
            JSONObject obj = array.optJSONObject(i);
            if (obj == null) {
                continue;
            }
            Bitmap bitmap = null;
            String imagePath = obj.optString("imagePath", null);
            String imageData = obj.optString("imageData", null);
            if (imagePath != null && !imagePath.isEmpty()) {
                File file = resolveLocalFile(imagePath);
                if (file != null) {
                    bitmap = BitmapFactory.decodeFile(file.getAbsolutePath());
                }
            } else if (imageData != null && !imageData.isEmpty()) {
                String clean = imageData.contains(",") ? imageData.substring(imageData.indexOf(',') + 1) : imageData;
                byte[] bytes = Base64.decode(clean, Base64.DEFAULT);
                bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
            }
            if (bitmap == null) {
                continue;
            }
            OverlayImage overlay = new OverlayImage();
            overlay.bitmap = bitmap;
            overlay.x = obj.optDouble("x", 50);
            overlay.y = obj.optDouble("y", 50);
            float widthPercent = (float) obj.optDouble("width", 20);
            float heightPercent = (float) obj.optDouble("height", 20);
            overlay.drawWidth = WIDTH * (widthPercent / 100f);
            overlay.drawHeight = HEIGHT * (heightPercent / 100f);
            if (obj.has("startTime") && !obj.isNull("startTime")) {
                overlay.startTime = obj.optDouble("startTime");
            }
            if (obj.has("endTime") && !obj.isNull("endTime")) {
                overlay.endTime = obj.optDouble("endTime");
            }
            list.add(overlay);
        }
        return list;
    }

    private static int parseColor(String value) {
        try {
            return Color.parseColor(value);
        } catch (Exception e) {
            return Color.WHITE;
        }
    }

    /** Decode / resample only the requested clip to stereo 16-bit PCM at 44.1kHz. */
    private static PcmAudio decodeAudioToPcm(File audioFile, double startTimeSec, Double durationSec) throws IOException {
        String name = audioFile.getName().toLowerCase();
        short[] monoOrStereo;
        int sampleRate;
        int channels;

        if (name.endsWith(".wav") || isWavFile(audioFile)) {
            WavData wav = parseWavClip(audioFile, startTimeSec, durationSec);
            monoOrStereo = wav.samples;
            sampleRate = wav.sampleRate;
            channels = wav.channels;
            // Already trimmed at source sample rate — resample then return
            short[] stereo44k = resampleToStereo44100(monoOrStereo, sampleRate, channels);
            PcmAudio pcm = new PcmAudio();
            pcm.samples = stereo44k;
            pcm.sampleRate = AUDIO_SAMPLE_RATE;
            pcm.channelCount = AUDIO_CHANNEL_COUNT;
            pcm.durationSec = stereo44k.length / (double) (AUDIO_SAMPLE_RATE * AUDIO_CHANNEL_COUNT);
            return pcm;
        }

        DecodedAudio decoded = decodeWithMediaCodec(audioFile, startTimeSec, durationSec);
        short[] stereo44k = resampleToStereo44100(decoded.samples, decoded.sampleRate, decoded.channelCount);
        PcmAudio pcm = new PcmAudio();
        pcm.samples = stereo44k;
        pcm.sampleRate = AUDIO_SAMPLE_RATE;
        pcm.channelCount = AUDIO_CHANNEL_COUNT;
        pcm.durationSec = stereo44k.length / (double) (AUDIO_SAMPLE_RATE * AUDIO_CHANNEL_COUNT);
        return pcm;
    }

    private static boolean isWavFile(File file) throws IOException {
        try (FileInputStream in = new FileInputStream(file)) {
            byte[] header = new byte[12];
            if (in.read(header) < 12) {
                return false;
            }
            return header[0] == 'R' && header[1] == 'I' && header[2] == 'F' && header[3] == 'F'
                    && header[8] == 'W' && header[9] == 'A' && header[10] == 'V' && header[11] == 'E';
        }
    }

    private static WavData parseWavClip(File file, double startTimeSec, Double durationSec) throws IOException {
        try (FileInputStream in = new FileInputStream(file)) {
            byte[] riff = new byte[12];
            if (in.read(riff) < 12) {
                throw new IOException("WAV too small");
            }
            int channels = 0;
            int sampleRate = 0;
            int bitsPerSample = 0;
            long dataOffset = -1;
            long dataSize = 0;
            long position = 12;

            while (true) {
                byte[] chunkHeader = new byte[8];
                int read = in.read(chunkHeader);
                if (read < 8) {
                    break;
                }
                position += 8;
                String chunkId = new String(chunkHeader, 0, 4);
                int chunkSize = ByteBuffer.wrap(chunkHeader, 4, 4).order(ByteOrder.LITTLE_ENDIAN).getInt() & 0xffffffff;
                if ("fmt ".equals(chunkId)) {
                    byte[] fmt = new byte[chunkSize];
                    if (in.read(fmt) < chunkSize) {
                        throw new IOException("Truncated fmt chunk");
                    }
                    ByteBuffer fmtBuf = ByteBuffer.wrap(fmt).order(ByteOrder.LITTLE_ENDIAN);
                    fmtBuf.getShort(); // audio format
                    channels = fmtBuf.getShort() & 0xffff;
                    sampleRate = fmtBuf.getInt();
                    fmtBuf.getInt(); // byte rate
                    fmtBuf.getShort(); // block align
                    bitsPerSample = fmtBuf.getShort() & 0xffff;
                    position += chunkSize;
                } else if ("data".equals(chunkId)) {
                    dataOffset = position;
                    dataSize = chunkSize & 0xffffffffL;
                    break;
                } else {
                    long skip = chunkSize + (chunkSize & 1);
                    long skipped = in.skip(skip);
                    position += skipped;
                }
            }

            if (dataOffset < 0 || channels <= 0 || sampleRate <= 0 || bitsPerSample <= 0) {
                throw new IOException("Invalid WAV format");
            }

            int bytesPerSample = bitsPerSample / 8;
            int frameBytes = bytesPerSample * channels;
            long totalFrames = dataSize / frameBytes;
            long startFrame = Math.max(0, Math.round(startTimeSec * sampleRate));
            if (startFrame >= totalFrames) {
                throw new IOException("startTime beyond audio length");
            }
            long frameCount = totalFrames - startFrame;
            if (durationSec != null && durationSec > 0) {
                frameCount = Math.min(frameCount, Math.round(durationSec * sampleRate));
            }
            // Cap clip length to avoid OOM (Instagram stories typically short)
            frameCount = Math.min(frameCount, sampleRate * 60L);

            long byteOffset = dataOffset + startFrame * frameBytes;
            long byteCount = frameCount * frameBytes;
            // Seek to clip start
            long toSkip = byteOffset - position;
            while (toSkip > 0) {
                long skipped = in.skip(toSkip);
                if (skipped <= 0) {
                    break;
                }
                toSkip -= skipped;
            }

            int sampleCount = (int) (frameCount * channels);
            short[] samples = new short[sampleCount];
            byte[] buffer = new byte[8192];
            int sampleIndex = 0;
            long remaining = byteCount;
            while (remaining > 0 && sampleIndex < sampleCount) {
                int toRead = (int) Math.min(buffer.length, remaining);
                int n = in.read(buffer, 0, toRead);
                if (n <= 0) {
                    break;
                }
                remaining -= n;
                ByteBuffer data = ByteBuffer.wrap(buffer, 0, n).order(ByteOrder.LITTLE_ENDIAN);
                if (bitsPerSample == 16) {
                    while (data.remaining() >= 2 && sampleIndex < sampleCount) {
                        samples[sampleIndex++] = data.getShort();
                    }
                } else if (bitsPerSample == 8) {
                    while (data.remaining() >= 1 && sampleIndex < sampleCount) {
                        samples[sampleIndex++] = (short) ((data.get() & 0xff) - 128 << 8);
                    }
                } else if (bitsPerSample == 24) {
                    while (data.remaining() >= 3 && sampleIndex < sampleCount) {
                        int b0 = data.get() & 0xff;
                        int b1 = data.get() & 0xff;
                        int b2 = data.get();
                        int sample = (b2 << 16) | (b1 << 8) | b0;
                        samples[sampleIndex++] = (short) (sample >> 8);
                    }
                } else {
                    throw new IOException("Unsupported WAV bit depth: " + bitsPerSample);
                }
            }

            WavData wav = new WavData();
            wav.samples = samples;
            wav.sampleRate = sampleRate;
            wav.channels = channels;
            return wav;
        }
    }

    private static DecodedAudio decodeWithMediaCodec(File audioFile, double startTimeSec, Double durationSec) throws IOException {
        android.media.MediaExtractor extractor = new android.media.MediaExtractor();
        extractor.setDataSource(audioFile.getAbsolutePath());
        int track = -1;
        MediaFormat format = null;
        for (int i = 0; i < extractor.getTrackCount(); i++) {
            MediaFormat f = extractor.getTrackFormat(i);
            String mime = f.getString(MediaFormat.KEY_MIME);
            if (mime != null && mime.startsWith("audio/")) {
                track = i;
                format = f;
                break;
            }
        }
        if (track < 0 || format == null) {
            extractor.release();
            throw new IOException("No audio track found in " + audioFile.getName());
        }
        extractor.selectTrack(track);
        long startUs = (long) (Math.max(0, startTimeSec) * 1_000_000L);
        long endUs = Long.MAX_VALUE;
        if (durationSec != null && durationSec > 0) {
            endUs = startUs + (long) (durationSec * 1_000_000L);
        }
        extractor.seekTo(startUs, android.media.MediaExtractor.SEEK_TO_CLOSEST_SYNC);

        String mime = format.getString(MediaFormat.KEY_MIME);
        MediaCodec decoder = MediaCodec.createDecoderByType(mime);
        decoder.configure(format, null, null, 0);
        decoder.start();

        List<Short> pcmList = new ArrayList<>();
        MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
        boolean inputDone = false;
        boolean outputDone = false;
        int sampleRate = format.containsKey(MediaFormat.KEY_SAMPLE_RATE)
                ? format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                : AUDIO_SAMPLE_RATE;
        int channelCount = format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)
                ? format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                : 1;
        // Cap ~60s of PCM shorts to avoid OOM
        int maxSamples = sampleRate * channelCount * 60;

        while (!outputDone) {
            if (!inputDone) {
                int inIndex = decoder.dequeueInputBuffer(TIMEOUT_US);
                if (inIndex >= 0) {
                    ByteBuffer buffer = decoder.getInputBuffer(inIndex);
                    if (buffer == null) {
                        continue;
                    }
                    int sampleSize = extractor.readSampleData(buffer, 0);
                    long sampleTime = extractor.getSampleTime();
                    if (sampleSize < 0 || sampleTime > endUs) {
                        decoder.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                        inputDone = true;
                    } else {
                        decoder.queueInputBuffer(inIndex, 0, sampleSize, sampleTime, 0);
                        extractor.advance();
                    }
                }
            }

            int outIndex = decoder.dequeueOutputBuffer(info, TIMEOUT_US);
            if (outIndex >= 0) {
                ByteBuffer out = decoder.getOutputBuffer(outIndex);
                if (out != null && info.size > 0 && info.presentationTimeUs >= startUs) {
                    out.position(info.offset);
                    out.limit(info.offset + info.size);
                    while (out.remaining() >= 2 && pcmList.size() < maxSamples) {
                        pcmList.add(out.getShort());
                    }
                    if (pcmList.size() >= maxSamples) {
                        outputDone = true;
                    }
                }
                decoder.releaseOutputBuffer(outIndex, false);
                if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                    outputDone = true;
                }
            } else if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                MediaFormat newFormat = decoder.getOutputFormat();
                if (newFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                    sampleRate = newFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE);
                }
                if (newFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                    channelCount = newFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT);
                }
            }
        }

        decoder.stop();
        decoder.release();
        extractor.release();

        short[] samples = new short[pcmList.size()];
        for (int i = 0; i < pcmList.size(); i++) {
            samples[i] = pcmList.get(i);
        }
        DecodedAudio decoded = new DecodedAudio();
        decoded.samples = samples;
        decoded.sampleRate = sampleRate;
        decoded.channelCount = channelCount;
        return decoded;
    }

    private static short[] resampleToStereo44100(short[] input, int sampleRate, int channels) {
        if (channels <= 0) {
            channels = 1;
        }
        int inputFrames = input.length / channels;
        double ratio = AUDIO_SAMPLE_RATE / (double) sampleRate;
        int outputFrames = Math.max(1, (int) Math.round(inputFrames * ratio));
        short[] output = new short[outputFrames * AUDIO_CHANNEL_COUNT];
        for (int i = 0; i < outputFrames; i++) {
            double srcPos = i / ratio;
            int idx = (int) Math.floor(srcPos);
            if (idx >= inputFrames) {
                idx = inputFrames - 1;
            }
            int base = idx * channels;
            short left;
            short right;
            if (channels == 1) {
                left = right = input[base];
            } else {
                left = input[base];
                right = input[base + 1];
            }
            output[i * 2] = left;
            output[i * 2 + 1] = right;
        }
        return output;
    }

    private static void encodeYUV420SP(byte[] yuv420sp, int[] argb, int width, int height) {
        int frameSize = width * height;
        int yIndex = 0;
        int uvIndex = frameSize;
        for (int j = 0; j < height; j++) {
            for (int i = 0; i < width; i++) {
                int color = argb[j * width + i];
                int r = (color >> 16) & 0xff;
                int g = (color >> 8) & 0xff;
                int b = color & 0xff;
                int y = ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16;
                int u = ((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128;
                int v = ((112 * r - 94 * g - 18 * b + 128) >> 8) + 128;
                yuv420sp[yIndex++] = (byte) Math.max(0, Math.min(255, y));
                if ((j % 2) == 0 && (i % 2) == 0) {
                    yuv420sp[uvIndex++] = (byte) Math.max(0, Math.min(255, u));
                    yuv420sp[uvIndex++] = (byte) Math.max(0, Math.min(255, v));
                }
            }
        }
    }

    private static final class OverlayText {
        String text;
        double x;
        double y;
        float fontSize;
        int color;
        boolean bold;
        boolean italic;
        Double startTime;
        Double endTime;
        float shadowRadius;
        float shadowDx;
        float shadowDy;
        int shadowColor = Color.BLACK;
    }

    private static final class OverlayImage {
        Bitmap bitmap;
        double x;
        double y;
        float drawWidth;
        float drawHeight;
        Double startTime;
        Double endTime;
    }

    private static final class PcmAudio {
        short[] samples;
        int sampleRate;
        int channelCount;
        double durationSec;
    }

    private static final class WavData {
        short[] samples;
        int sampleRate;
        int channels;
    }

    private static final class DecodedAudio {
        short[] samples;
        int sampleRate;
        int channelCount;
    }
}
