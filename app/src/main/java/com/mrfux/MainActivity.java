package com.mrfux;

import android.app.AlertDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.app.Activity;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.NumberPicker;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.TextView;
import android.widget.Toast;

import com.mrfux.audio.PlaybackController;
import com.mrfux.model.NoteSequenceModel;
import com.mrfux.model.Violation;
import com.mrfux.ui.StaffView;

import java.io.File;
import java.io.FilenameFilter;
import java.util.List;

public class MainActivity extends Activity {

    // ---------------------------------------------------------------
    // State
    // ---------------------------------------------------------------
    private NoteSequenceModel model;
    private PlaybackController player;

    private int     cursor      = 1;
    private int     activeVoice = 1;  // 1=CF, 2=CP
    private boolean checkMode   = false;
    private int     issueIdx    = 0;  // 0-indexed within violations at cursor
    private boolean narrowLayout = true;
    private String  lastFilename = "exercise";

    // Flash for related notes in check mode
    private int     flashLevel   = 6;
    private final Handler flashHandler  = new Handler(Looper.getMainLooper());
    private Runnable flashRunnable;

    // ---------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------
    private StaffView staffView;
    private TextView  statusLeft;
    private TextView  statusRight;
    private Button    btnVoiceToggle;
    private Button    btnPlay;
    private Button    btnCheck;

    // ---------------------------------------------------------------
    // Activity lifecycle
    // ---------------------------------------------------------------

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        model  = new NoteSequenceModel();
        player = new PlaybackController(model);

        bindViews();
        bindListeners();
        updateStatusBar();
        refreshStaff();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (player.isPlaying()) player.stop();
        stopFlash();
    }

    // ---------------------------------------------------------------
    // View binding
    // ---------------------------------------------------------------

    private void bindViews() {
        staffView       = findViewById(R.id.staff_view);
        statusLeft      = findViewById(R.id.status_left);
        statusRight     = findViewById(R.id.status_right);
        btnVoiceToggle  = findViewById(R.id.btn_voice_toggle);
        btnPlay         = findViewById(R.id.btn_play);
        btnCheck        = findViewById(R.id.btn_check);

        staffView.setModel(model);
        staffView.setLayout(narrowLayout);
        staffView.setCursor(cursor);
        staffView.setActiveVoice(activeVoice);
    }

    private void bindListeners() {
        // Staff touch
        staffView.setListener(new StaffView.Listener() {
            @Override
            public void onCursorChanged(int step) {
                cursor = step;
                issueIdx = 0;
                staffView.setCursor(cursor);
                updateStatusBar();
                refreshStaff();
            }
            @Override
            public void onPitchSwipe(int diatonicSteps) {
                changePitch(diatonicSteps);
            }
        });

        // Navigation
        findViewById(R.id.btn_cursor_left).setOnClickListener(v -> moveCursor(-1));
        findViewById(R.id.btn_cursor_right).setOnClickListener(v -> moveCursor(1));
        findViewById(R.id.btn_pitch_up).setOnClickListener(v -> changePitch(1));
        findViewById(R.id.btn_pitch_down).setOnClickListener(v -> changePitch(-1));

        // Voice toggle
        btnVoiceToggle.setOnClickListener(v -> toggleVoice());

        // Play
        btnPlay.setOnClickListener(v -> {
            if (player.isPlaying()) {
                player.stop();
            } else {
                startPlayback(0);
            }
        });

        // Long-press play = solo active voice
        btnPlay.setOnLongClickListener(v -> {
            if (!player.isPlaying()) startPlayback(activeVoice);
            return true;
        });

        // Check mode
        btnCheck.setOnClickListener(v -> toggleCheckMode());

        // Settings
        findViewById(R.id.btn_settings).setOnClickListener(v -> showSettings());

        // Save / Load
        findViewById(R.id.btn_save).setOnClickListener(v -> showSaveDialog());
        findViewById(R.id.btn_load).setOnClickListener(v -> showLoadDialog());

        // Playback listener
        player.setListener(new PlaybackController.Listener() {
            @Override
            public void onStep(int step) {
                staffView.setPlayPos(step);
                staffView.setPlaying(true);
                btnPlay.setText("■");
            }
            @Override
            public void onStop() {
                staffView.setPlaying(false);
                staffView.setPlayPos(0);
                btnPlay.setText("▶");
                refreshStaff();
            }
        });
    }

    // ---------------------------------------------------------------
    // Navigation
    // ---------------------------------------------------------------

    private void moveCursor(int delta) {
        if (checkMode) {
            // In check mode: left/right navigates between issues at cursor
            List<Violation> vols = model.violationsAt(cursor, activeVoice);
            if (!vols.isEmpty()) {
                issueIdx = Math.max(0, Math.min(vols.size() - 1, issueIdx + delta));
                updateStatusBar();
                refreshStaff();
                return;
            }
        }
        cursor = Math.max(1, Math.min(model.getLength(), cursor + delta));
        issueIdx = 0;
        staffView.setCursor(cursor);
        updateStatusBar();
        refreshStaff();
    }

    private void changePitch(int diatonicSteps) {
        if (activeVoice == 1) {
            int cur = model.getCantus(cursor);
            model.setCantus(cursor, NoteSequenceModel.diatonicStep(cur, diatonicSteps));
        } else {
            int cur = model.getCounterpoint(cursor);
            model.setCounterpoint(cursor, NoteSequenceModel.diatonicStep(cur, diatonicSteps));
        }
        if (checkMode) {
            model.runChecks();
        }
        refreshStaff();
    }

    private void toggleVoice() {
        activeVoice = (activeVoice == 1) ? 2 : 1;
        issueIdx = 0;
        staffView.setActiveVoice(activeVoice);
        btnVoiceToggle.setText(activeVoice == 1 ? "CF" : "CP");
        updateStatusBar();
        refreshStaff();
    }

    // ---------------------------------------------------------------
    // Playback
    // ---------------------------------------------------------------

    private void startPlayback(int soloVoice) {
        player.start(soloVoice);
        btnPlay.setText("■");
        staffView.setPlaying(true);
    }

    // ---------------------------------------------------------------
    // Check mode
    // ---------------------------------------------------------------

    private void toggleCheckMode() {
        checkMode = !checkMode;
        if (checkMode) {
            model.runChecks();
            issueIdx = 0;
            startFlash();
            btnCheck.setText("Edit");
        } else {
            stopFlash();
            btnCheck.setText("Check");
        }
        staffView.setCheckMode(checkMode);
        updateStatusBar();
        refreshStaff();
    }

    private void startFlash() {
        flashLevel = 6;
        flashRunnable = new Runnable() {
            @Override public void run() {
                flashLevel = (flashLevel == 6) ? 12 : 6;
                refreshStaff();
                flashHandler.postDelayed(this, 600);
            }
        };
        flashHandler.postDelayed(flashRunnable, 600);
    }

    private void stopFlash() {
        if (flashRunnable != null) {
            flashHandler.removeCallbacks(flashRunnable);
            flashRunnable = null;
        }
    }

    // ---------------------------------------------------------------
    // Staff refresh
    // ---------------------------------------------------------------

    private void refreshStaff() {
        if (checkMode) {
            int len = model.getLength();
            int[] cfLevels = new int[len];
            int[] cpLevels = new int[len];
            StaffView.computeCheckLevels(
                    model.getViolations(),
                    cursor, activeVoice, issueIdx,
                    flashLevel, len,
                    cfLevels, cpLevels);
            staffView.setNoteLevels(cfLevels, cpLevels);
        }
        staffView.invalidate();
    }

    // ---------------------------------------------------------------
    // Status bar
    // ---------------------------------------------------------------

    private void updateStatusBar() {
        if (checkMode) {
            List<Violation> vols = model.violationsAt(cursor, activeVoice);
            if (!vols.isEmpty()) {
                Violation v = vols.get(Math.min(issueIdx, vols.size() - 1));
                statusLeft.setText(v.summary);
                statusLeft.setTextColor(0xFFFFFFFF);
                if (vols.size() > 1) {
                    statusRight.setText((issueIdx + 1) + "/" + vols.size());
                } else {
                    statusRight.setText("");
                }
            } else {
                statusLeft.setText("CHECK");
                statusLeft.setTextColor(0xFF666666);
                statusRight.setText("");
            }
        } else {
            statusLeft.setText(activeVoice == 1 ? "CF" : "CP");
            statusLeft.setTextColor(0xFF666666);
            statusRight.setText("");
        }
    }

    // ---------------------------------------------------------------
    // Settings dialog
    // ---------------------------------------------------------------

    private void showSettings() {
        View layout = getLayoutInflater().inflate(android.R.layout.simple_list_item_1, null);

        // Build a simple dialog manually
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle("Settings");

        // Length picker
        final NumberPicker lengthPicker = new NumberPicker(this);
        lengthPicker.setMinValue(4);
        lengthPicker.setMaxValue(NoteSequenceModel.MAX_LENGTH);
        lengthPicker.setValue(model.getLength());

        // Layout radio
        final RadioGroup layoutGroup = new RadioGroup(this);
        RadioButton narrowBtn = new RadioButton(this);
        narrowBtn.setText("Narrow");
        narrowBtn.setTextColor(0xFFFFFFFF);
        RadioButton normalBtn = new RadioButton(this);
        normalBtn.setText("Normal");
        normalBtn.setTextColor(0xFFFFFFFF);
        layoutGroup.addView(narrowBtn);
        layoutGroup.addView(normalBtn);
        if (narrowLayout) narrowBtn.setChecked(true);
        else              normalBtn.setChecked(true);

        android.widget.LinearLayout content = new android.widget.LinearLayout(this);
        content.setOrientation(android.widget.LinearLayout.VERTICAL);
        content.setPadding(48, 24, 48, 0);

        TextView lenLabel = new TextView(this);
        lenLabel.setText("Length");
        lenLabel.setTextColor(0xFFAAAAAA);
        content.addView(lenLabel);
        content.addView(lengthPicker);

        TextView layoutLabel = new TextView(this);
        layoutLabel.setText("Layout");
        layoutLabel.setTextColor(0xFFAAAAAA);
        content.addView(layoutLabel);
        content.addView(layoutGroup);

        builder.setView(content);
        builder.setPositiveButton("OK", (dialog, which) -> {
            int newLen = lengthPicker.getValue();
            if (newLen != model.getLength()) {
                model.setLength(newLen);
                cursor = Math.max(1, Math.min(cursor, newLen));
                issueIdx = 0;
                staffView.setCursor(cursor);
                if (checkMode) model.runChecks();
            }
            boolean newNarrow = narrowBtn.isChecked();
            if (newNarrow != narrowLayout) {
                narrowLayout = newNarrow;
                staffView.setLayout(narrowLayout);
            }
            updateStatusBar();
            refreshStaff();
        });
        builder.setNegativeButton("Cancel", null);
        builder.show();
    }

    // ---------------------------------------------------------------
    // Save dialog
    // ---------------------------------------------------------------

    private void showSaveDialog() {
        EditText input = new EditText(this);
        input.setText(lastFilename);
        input.setTextColor(0xFFFFFFFF);
        input.setHintTextColor(0xFF666666);
        input.selectAll();

        new AlertDialog.Builder(this)
                .setTitle("Save Exercise")
                .setView(input)
                .setPositiveButton("Save", (dialog, which) -> {
                    String name = input.getText().toString().trim();
                    if (name.isEmpty()) name = lastFilename;
                    saveWithConfirmation(name);
                })
                .setNegativeButton("Cancel", null)
                .show();
    }

    private void saveWithConfirmation(String name) {
        File file = saveFile(name);
        if (file.exists()) {
            final String finalName = name;
            new AlertDialog.Builder(this)
                    .setTitle("File Exists")
                    .setMessage("Overwrite \"" + name + "\"?")
                    .setPositiveButton("Overwrite", (d, w) -> doSave(finalName))
                    .setNegativeButton("Rename", (d, w) -> showSaveDialog())
                    .setNeutralButton("Cancel", null)
                    .show();
        } else {
            doSave(name);
        }
    }

    private void doSave(String name) {
        try {
            lastFilename = name;
            model.saveToFile(saveFile(name));
            Toast.makeText(this, "Saved: " + name, Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            Toast.makeText(this, "Save failed: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    // ---------------------------------------------------------------
    // Load dialog
    // ---------------------------------------------------------------

    private void showLoadDialog() {
        File dir = saveDir();
        File[] files = dir.listFiles((d, n) -> n.endsWith(".json"));
        if (files == null || files.length == 0) {
            Toast.makeText(this, "No saved exercises found.", Toast.LENGTH_SHORT).show();
            return;
        }
        String[] names = new String[files.length];
        for (int i = 0; i < files.length; i++) {
            names[i] = files[i].getName().replace(".json", "");
        }
        final File[] filesRef = files;
        new AlertDialog.Builder(this)
                .setTitle("Load Exercise")
                .setItems(names, (dialog, which) -> doLoad(filesRef[which]))
                .setNegativeButton("Cancel", null)
                .show();
    }

    private void doLoad(File file) {
        try {
            model.loadFromFile(file);
            lastFilename = file.getName().replace(".json", "");
            cursor = Math.max(1, Math.min(cursor, model.getLength()));
            issueIdx = 0;
            if (checkMode) { checkMode = false; stopFlash(); btnCheck.setText("Check"); }
            staffView.setModel(model);
            staffView.setCursor(cursor);
            staffView.setCheckMode(false);
            updateStatusBar();
            refreshStaff();
        } catch (Exception e) {
            Toast.makeText(this, "Load failed: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    // ---------------------------------------------------------------
    // File helpers
    // ---------------------------------------------------------------

    private File saveDir() {
        File dir = new File(getFilesDir(), "mr_fux");
        if (!dir.exists()) dir.mkdirs();
        return dir;
    }

    private File saveFile(String name) {
        return new File(saveDir(), name + ".json");
    }
}
