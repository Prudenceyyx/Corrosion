import codeanticode.syphon.*;
import processing.video.Capture;
//import gab.opencv.OpenCV;
//import gab.opencv.Contour;
import gab.opencv.*;
import java.awt.Rectangle;

SyphonServer server;
final int READ=1;
final int SENSE=2;
int STATE;

Capture cam;
OpenCV opencv;

int w = 320, h = 240;
int fps = 30;
//int zoom = 3;//Face
int zoom = 2;

// contour threshold ( 0 .. 255)
int threshold = 100;
// display options
boolean useROI = true;
boolean showOutput=true;
boolean showContours=true;
boolean showPolys;
boolean showBackground;
// drawing style

// counting the number of snapshots
int snapCount;

PImage bk;


int count=0;
int incre=10;

Rectangle[] faces;
int time;
int wait=1000;


void settings() {
  size(960, 540, P2D);
  //size(640, 360,P2D);
  //fullScreen();
  PJOGL.profile=1;
}

void setup() {
  for (String l : Capture.list()) {
    println(l);
  }
  // actual size, is a result of input resolution and zoom factor

  frameRate(fps);

  server = new SyphonServer(this, "Processing Syphon");
  // capture camera with input resolution
  //WebCam 1280, 720,30
  //    /3=320,  180
  //      
  //cam=new Capture(this,960,720,30);//try Webcam
  //cam=new Capture(this,480,270,30);//try Webcam
  cam=new Capture(this, Capture.list()[6]);
  //cam = new Capture(this, 320, 240, fps);//FaceCam
  cam.start();
  frameRate(30);
  // init OpenCV with input resolution
  opencv = new OpenCV(this, 480, 270);
  //opencv = new OpenCV(this, 480, 270);//try Webcam
  //opencv = new OpenCV(this, 320, 240);//FaceCam
  opencv.useGray();
  opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);
  //opencv.loadCascade(OpenCV.CASCADE_FULLBODY);
  //opencv.loadCascade(OpenCV.CASCADE_UPPERBODY);

  STATE=READ;

  opencv.useColor(RGB);

  while (opencv.width==0||opencv.height==0) {
    opencv.loadImage(cam);
  }

  bk=opencv.getSnapshot();
  time=millis();
}


void draw() {
  scale(zoom);
  opencv.loadImage(cam); 
  image(opencv.getInput(), 0, 0);
  faces=faceDetect();
  STATE=faces.length>0?SENSE:READ;
  if (STATE==READ) { 
    //count-=10;
    count=0;
    count=constrain(count, 0, 360);
    //reset background
    //if(frameCount%50==0)
    if(millis()-time>3000){
    resetbackground();
    time=millis();
    }
  } else if (STATE==SENSE) {
    if (frameCount%2==0) {
      count=calculating(count);
      println(count);
    }
    //drawFaces(faces);
    //faceROI(faces);
    changecolor(faces);
  }
  opencv.releaseROI();
  if (showBackground) 
    image(bk, 0, 0);
  
  server.sendScreen();
}

void resetbackground() {
  if (millis()-time>wait) {
    bk=opencv.getSnapshot();
    time=millis();
  }
}

int calculating(int c) { 
  if (c+incre>360) {
    //incre=-incre;
  }
  c+=incre;
  c=constrain(c, 0, 360);
  return c;
}

void changecolor(Rectangle[] faces) {
  float centerx=faces[0].x+faces[0].width/2;
  float centery=faces[0].y+faces[0].height/2;
  float neww=faces[0].width*6;
  float newh=faces[0].height*9;
  int x=constrain(int(centerx-neww/2),0,width*zoom);
  int y=constrain(int(faces[0].y-40),0,height*zoom);
  int w=int(neww);
  int h=int(newh);
  //opencv.brightness(150);//just a test

  opencv.useColor(RGB);       //FIXED: Grey Image
  //image(opencv.getOutput(), 0, 0);
  //TODO: Smooth Color Transition
  bk.loadPixels();
  colorMode(RGB, 360);
  PImage replace=createImage(w, h, RGB);
  replace.copy(opencv.getOutput(), x, y, w, h, 0, 0, replace.width, replace.height);
  replace.loadPixels();



  for (int rx=0; rx<replace.width; rx++) {
    for (int ry=0; ry<replace.height; ry++) {
      color oriColor=replace.get(rx, ry);
      color bkColor=bk.get(rx+x, ry+y);
      float tred=map(count, 0, 360, red(oriColor), red(bkColor));
      float tgreen=map(count, 0, 360, green(oriColor), green(bkColor));
      float tblue=map(count, 0, 360, blue(oriColor), blue(bkColor));
      color trueColor=color(tred, tgreen, tblue);
      replace.set(rx, ry, trueColor);
    }
  }
  replace.updatePixels();
  image(replace, x, y);
}

Rectangle[] faceDetect() {
  //opencv.loadImage(cam);
  Rectangle[] faces = opencv.detect();
  // draw input cam
  //image(opencv.getInput(), 0, 0);
  // show performance and number of detected faces on the console
  if (frameCount % 50 == 0) {
    println("Frame rate:", round(frameRate), "fps");
    println("Number of faces:", faces.length);
  }

  return faces;
}


void drawFaces(Rectangle[] faces) {
  // draw rectangles around detected faces
  fill(255, 0);
  strokeWeight(3);
  for (int i = 0; i < faces.length; i++) {
    rect(faces[i].x, faces[i].y, faces[i].width, faces[i].height);
  }
}

void faceROI(Rectangle[] faces) {
  if (faces.length>0) {
    //pushMatrix();
    if (useROI) {
      int x=int(faces[0].x);
      int y=int(faces[0].y);
      int w=int(faces[0].width);
      int h=int(faces[0].height);
      //w=x+w>width-1?width-x-1:w;
      //h=y+h>height-1?height-y-1:h;
      opencv.setROI(x, y, w, h);

      //opencv.setROI(mouseX/3, mouseY/3, 30, 30);

      //TODO: Bug: When faces' boundary excess size, ROI doesn't work, but still translated
      //opencv.brightness(150);//just a test


      //opencv.useColor(RGB);       //FIXED: Grey Image
      //image(opencv.getOutput(), 0, 0);
    }
    //faceContour(opencv, faces);
    //popMatrix();
  }
  //opencv.releaseROI();
}


void faceContour(OpenCV o, Rectangle[] faces) {
  o.threshold(75);
  ArrayList<Contour> contours = o.findContours();
  //PImage output = o.getOutput();
  //image(output , 0, 0);

  smooth();
  strokeWeight(2);
  strokeJoin(ROUND);
  // draw on top of output image
  for (Contour contour : contours) {
    fill(255, 150);
    // draw the contour
    if (true) {
      color contourColor = color(255, 50, 50, 150);
      stroke(contourColor);
      contour.draw();
    }
  }

  // show performance and number of detected contours on the console
  if (snapCount % 10 == 0) {
    println("======= Frame:" + nfs(snapCount, 5), "=======");
    println("Threshold: ", threshold);
    println("Camera frame rate:", round(cam.frameRate), "fps");
    println("Sketch frame rate:", round(frameRate), "fps");
    println("Number of contours:", contours.size());
  }

  // count number of snapshots taken and processed
  snapCount++;
}






// read a new frame when it's available
void captureEvent(Capture c) {
  c.read();
}
void keyPressed() {

  switch(key) {

  case 'b':
    //opencv.loadImage(cam);
    opencv.useColor(RGB); 
    bk=opencv.getSnapshot();
    break;

  case 's':
    showBackground = !showBackground;
    break;

  case '+':
    threshold += 10;
    break;

  case '-':
    threshold -= 10;
    break;

  case 'o':
    showOutput = !showOutput;
    return;

  case 'c':
    showContours = !showContours;
    return;

  case 'p':
    showPolys = !showPolys;
    return;

  case 'u':
    useROI = !useROI;
  }
  if (!useROI) {
    opencv.releaseROI();
  }

  // constrain threshold to the valid domain
  threshold = constrain(threshold, 0, 255);

  // update OpenCV threshold settings
  opencv.threshold(threshold);
}