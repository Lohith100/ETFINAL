import g4p_controls.*;
import processing.serial.*;
import javax.swing.*;
import java.awt.*;
import java.awt.event.*;

processing.serial.Serial myPort; // Explicitly specify the package for Serial
PFont pFont, placeholderFont;
Font awtFont;

GDropList portList;
GButton refreshButton, applyButton, themeButton, clearButton;
GTextField baudRateInput;

int buttonWidth = 160;
int buttonHeight = 100;

GButton offButton, laserOnButton, laserOffButton, autoButton, noDataButton;
GButton binaryButton, manualButton, sensorButton, energyButton, dataButton, dumpButton;

String binaryValue = "";
String manualValue = "";
String sensorValue = "";
String energyValue = "";
String dataValue = "";
String dumpValue = "";

GTextField binaryInput, manualInput, sensorInput, energyInput, dataInput, dumpInput;
GTextField focusedInput = null;

boolean newDataReceived = false;

int defaultBaudRate = 115200;
boolean isDarkTheme = false;

JTextArea receivedDataArea;

javax.swing.JFrame frame;
java.awt.Canvas canvas;

int _wndW = 1600;
int _wndH = 950;

PImage logo;

void setup() {
  size(_wndW, _wndH);
  //surface.setResizable(true); 
  //noLoop();
  //surface.setResizable(true);
  G4P.setGlobalColorScheme(GCScheme.BLUE_SCHEME);

  frame = (javax.swing.JFrame) ((processing.awt.PSurfaceAWT.SmoothCanvas) surface.getNative()).getFrame();
  canvas = (processing.awt.PSurfaceAWT.SmoothCanvas) ((processing.awt.PSurfaceAWT)surface).getNative();
  frame.setBounds(500, 500, _wndW, _wndH);

  receivedDataArea = new JTextArea();
  awtFont = new Font("Arial", Font.PLAIN, 18); // Increase font size
  receivedDataArea.setFont(awtFont);
  receivedDataArea.setEditable(false);
  receivedDataArea.setLineWrap(false);
  receivedDataArea.setWrapStyleWord(true);
  JScrollPane scrollPane = new JScrollPane(receivedDataArea);
  scrollPane.setBounds(560, 35, 1000, 840);

  // Remove and re-add the canvas and scrollPane
  frame.remove(canvas);
  frame.add(scrollPane);
  frame.add(canvas);

  frame.setVisible(true);

  frame.addComponentListener(new ComponentAdapter() {
    @Override
      public void componentResized(ComponentEvent e) {
      int textAreaWidth = frame.getWidth() - 600;
      int textAreaHeight = frame.getHeight() - 90;
      scrollPane.setBounds(560, 35, textAreaWidth, textAreaHeight);
    }
  }
  );

  portList = new GDropList(this, 50, 30, 200, 100, 5);
  portList.addEventHandler(this, "portListEvent");

  refreshPorts(); // Attempt to refresh ports at startup

  refreshButton = new GButton(this, 270, 30, 100, 20, "Refresh Ports");
  refreshButton.addEventHandler(this, "refreshPortsEvent");

  baudRateInput = new GTextField(this, 400, 30, 150, 20);
  baudRateInput.setText(str(defaultBaudRate));

  applyButton = new GButton(this, 400, 55, 100, 20, "Apply");
  applyButton.addEventHandler(this, "applySettingsEvent");

  themeButton = new GButton(this, 1200, 15, 100, 20, "Theme");
  themeButton.addEventHandler(this, "themeButtonEvent");

  clearButton = new GButton(this, 1400, 15, 100, 20, "Clear");
  clearButton.addEventHandler(this, "clearButtonEvent");

  pFont = createFont("Arial", 12, true);
  placeholderFont = createFont("Arial", 12, true);

  offButton = new GButton(this, 50, 100, buttonWidth, buttonHeight, "Off");
  offButton.addEventHandler(this, "offButtonEvent");
  laserOnButton = new GButton(this, 220, 100, buttonWidth, buttonHeight, "Laser On");
  laserOnButton.addEventHandler(this, "laserOnButtonEvent");
  laserOffButton = new GButton(this, 390, 100, buttonWidth, buttonHeight, "Laser Off");
  laserOffButton.addEventHandler(this, "laserOffButtonEvent");
  autoButton = new GButton(this, 50, 520, buttonWidth, buttonHeight, "Auto");
  autoButton.addEventHandler(this, "autoButtonEvent");
  noDataButton = new GButton(this, 220, 520, buttonWidth, buttonHeight, "No Data");
  noDataButton.addEventHandler(this, "noDataButtonEvent");

  binaryButton = new GButton(this, 50, 230, buttonWidth, buttonHeight, "Binary\n (5cm-750cm)");
  binaryButton.addEventHandler(this, "binaryButtonEvent");
  manualButton = new GButton(this, 220, 230, buttonWidth, buttonHeight, "Manual\n (4cm-750cm)");
  manualButton.addEventHandler(this, "manualButtonEvent");
  sensorButton = new GButton(this, 390, 230, buttonWidth, buttonHeight, "Sensor\n (5cm-750cm)");
  sensorButton.addEventHandler(this, "sensorButtonEvent");
  energyButton = new GButton(this, 390, 380, buttonWidth, buttonHeight, "Energy\n (0-255)");
  energyButton.addEventHandler(this, "energyButtonEvent");
  dataButton = new GButton(this, 50, 380, buttonWidth, buttonHeight, "Data");
  dataButton.addEventHandler(this, "dataButtonEvent");
  dumpButton = new GButton(this, 220, 380, buttonWidth, buttonHeight, "Dump");
  dumpButton.addEventHandler(this, "dumpButtonEvent");

  binaryInput = new GTextField(this, 50, 350, 160, 20);
  binaryInput.setPromptText("Type Distance Here");
  manualInput = new GTextField(this, 220, 350, 160, 20);
  manualInput.setPromptText("Type Distance Here");
  sensorInput = new GTextField(this, 390, 350, 160, 20);
  sensorInput.setPromptText("Type Distance Here");
  dataInput = new GTextField(this, 50, 490, 160, 20);
  dataInput.setPromptText("Type File Name Here");
  dumpInput = new GTextField(this, 220, 490, 160, 20);
  dumpInput.setPromptText("Type File Name Here");
  energyInput = new GTextField(this, 390, 490, 160, 20);
  energyInput.setPromptText("Type Energy Here");

  // Load the logo image
  logo = loadImage("logo.jpg");

  // Non-blocking thread to check port disconnection
  Thread portMonitorThread = new Thread(new Runnable() {
    public void run() {
      while (true) {
        monitorSerialPort();
        try {
          Thread.sleep(500); // Sleep instead of delay
        }
        catch (InterruptedException e) {
          e.printStackTrace();
        }
      }
    }
  }
  );
  portMonitorThread.start();

  // Start a separate thread for reading serial data
  Thread serialThread = new Thread(new Runnable() {
    public void run() {
      while (true) {
        if (myPort != null && myPort.available() > 0) {
          serialEvent(myPort);
        }
        try {
          Thread.sleep(10); // Sleep instead of delay
        }
        catch (InterruptedException e) {
          e.printStackTrace();
        }
      }
    }
  }
  );
  serialThread.start();
}

void draw() {
  if (isDarkTheme) {
    background(50);
    fill(255);
  } else {
    background(240);
    fill(0);
  }
  textSize(25);
  text("Enactive Torch", 50, 80);

  text("Output from EnactiveTorch:", 560, 25);

  // Display the logo below the buttons
  if (logo != null) {
    image(logo, 50, 650); // Adjust the position as needed
  }
}

void serialEvent(processing.serial.Serial myPort) {
  try {
    String inData = myPort.readStringUntil('\n');
    if (inData != null) {
      SwingUtilities.invokeLater(new Runnable() {
        public void run() {
          receivedDataArea.append(inData.trim() + "\n");
        }
      }
      );
    }
  }
  catch (Exception e) {
    e.printStackTrace();
  }
}

// This function checks if the serial port has been disconnected or if it is not available
void monitorSerialPort() {
  if (myPort != null && !myPort.active()) {  // If the port is no longer active
    myPort.stop();
    myPort = null;
    SwingUtilities.invokeLater(new Runnable() {
      public void run() {
        receivedDataArea.append("[Warning] Serial port disconnected!\n");
      }
    }
    );
  }
}

public void portListEvent(GDropList list, GEvent event) {
  if (event == GEvent.SELECTED) {
    applySettings();
  }
}

void refreshPortsEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    refreshPorts();
  }
}

void applySettingsEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    applySettings();
  }
}

void offButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    sendCommand("off");
  }
}

void laserOnButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    sendCommand("laser_on");
  }
}

void laserOffButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    sendCommand("laser_off");
  }
}

void autoButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    sendCommand("auto");
  }
}

void noDataButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    sendCommand("nodata");
  }
}

void binaryButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    sendCommandFromInput(button, binaryInput, "binary", 5, 750);
  }
}

void manualButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    sendCommandFromInput(button, manualInput, "manual", 4, 750);
  }
}

void sensorButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    sendCommandFromInput(button, sensorInput, "sensor", 5, 750);
  }
}

void energyButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    sendCommandFromInput(button, energyInput, "energy", 0, 255);
  }
}

void dataButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    sendCommandFromInput(button, dataInput, "data", 0, Integer.MAX_VALUE);
  }
}

void dumpButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    dumpValue = dumpInput.getText();
    if (isValidFileName(dumpValue)) {
      sendCommand("dump" + dumpValue);
    } else {
      showError("Invalid dump input. Please enter a valid file name.");
    }
  }
}

void refreshPorts() {
  // Check for available ports and handle gracefully if no ports are found
  String[] ports = processing.serial.Serial.list();
  if (ports.length > 0) {
    portList.setItems(ports, 0); // Populate dropdown with available ports
  } else {
    portList.setItems(new String[] { "No ports available" }, 0); // Show warning in dropdown
    JOptionPane.showMessageDialog(null, "No serial ports available. Please connect a device and refresh.", "Port Error", JOptionPane.WARNING_MESSAGE);
  }
}

void applySettings() {
  // Stop previous serial port if necessary
  if (portList != null && portList.getSelectedIndex() >= 0) {
    String selectedPort = portList.getSelectedText();
    if (!selectedPort.equals("No ports available")) {
      int baudRate = int(baudRateInput.getText());
      if (myPort != null) {
        myPort.stop();
      }
      delay(100);
      try {
        myPort = new processing.serial.Serial(this, selectedPort, baudRate);
        JOptionPane.showMessageDialog(null, "Serial port connected: " + selectedPort, "Success", JOptionPane.INFORMATION_MESSAGE);
      }
      catch (Exception e) {
        JOptionPane.showMessageDialog(null, "Failed to open the selected port. It might be busy or unavailable.", "Port Error", JOptionPane.ERROR_MESSAGE);
      }
    }
  } else {
    JOptionPane.showMessageDialog(null, "Please select a valid serial port.", "Port Error", JOptionPane.WARNING_MESSAGE);
  }
}

boolean isValidInput(String input, int minValue, int maxValue) {
  try {
    int value = int(input);
    return value >= minValue && value <= maxValue;
  }
  catch (NumberFormatException e) {
    return false;
  }
}

boolean isValidFileName(String fileName) {
  return fileName.matches("^[a-zA-Z0-9._-]+$");
}

void showError(String message) {
  JOptionPane.showMessageDialog(null, message, "Input Error", JOptionPane.ERROR_MESSAGE);
}

void sendCommand(String command) {
  if (myPort != null) {
    myPort.write(command + "\n");
  }
}

void sendCommandFromInput(GButton button, GTextField input, String prefix, int minValue, int maxValue) {
  String value = input.getText();
  if (value.isEmpty()) {
    showError("Please provide a value for " + prefix + ".");
    return;
  }
  if (isValidInput(value, minValue, maxValue)) {
    sendCommand(prefix + value);
  } else {
    showError("Invalid input for " + prefix + ". Please enter a value between " + minValue + " and " + maxValue + ".");
  }
}

void themeButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    isDarkTheme = !isDarkTheme;
    G4P.setGlobalColorScheme(isDarkTheme ? GCScheme.BLUE_SCHEME : GCScheme.BLUE_SCHEME);
    updateUITheme();
  }
}

void clearButtonEvent(GButton button, GEvent event) {
  if (event == GEvent.CLICKED) {
    receivedDataArea.setText("");
  }
}

void updateUITheme() {
  if (isDarkTheme) {
    background(50);
    fill(255);
  } else {
    background(240);
    fill(0);
  }
  // Update other UI elements here as needed
}
