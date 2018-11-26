unit uMain;

interface

uses
  stringx, tickcount, systemx,typex, Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, FrameTotalDebug, simplequeue, commandprocessor, anoncommand, globalmultiqueue, better_collections, linked_list,
  Vcl.Imaging.jpeg, fastbitmap, easyimage, debug, pngimage;

const
  MIN_PRIME = 1000000000;
  MAX_PRIME = 1000001000;

type
  TQueueItem_IsPrime = class(TQueueItem)
  protected
    procedure DoExecute; override;
  public
    in_n: ni;
    out_isPrime: boolean;
  end;


  TCommand_IsPrime = class(TCommand)
  protected
    procedure DoExecute; override;
  public
    in_n: ni;
    out_isPrime: boolean;
  end;

  TForm1 = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    panFrameHost: TPanel;
    Splitter1: TSplitter;
    btnQueues: TButton;
    lblResult: TLabel;
    tmCheckCommand: TTimer;
    lblResult2: TLabel;
    btnCommands: TButton;
    Image1: TImage;
    Button1: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnQueuesClick(Sender: TObject);
    procedure lblResultClick(Sender: TObject);
    procedure tmCheckCommandTimer(Sender: TObject);
    procedure TabSheet1ContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure btnCommandsClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    activecmd: TCommand;
    { Private declarations }
  public
    { Public declarations }
    procedure RefreshProcInfo;
    procedure UpdateState;
    procedure TileNotify(src, dest: TFastBitmap; region: TRect; state: TTileState);
  end;


function CheckIsPrime(n: int64; p: PProgress): boolean;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.btnQueuesClick(Sender: TObject);
var
  ac: TAnonymousCommand<ni>;
  res: ni;
  tmStart,tmEnd: ticker;
begin
  //
  res := 0;
  RefreshProcInfo;

  tmStart := getticker;

  ac := TAnonymousCommand<ni>.create(
          function: ni
          var
            x: ni;
            qi: TQueueItem_IsPrime;
          begin
            res := 0;
            ac.Status := 'Creating Queue Items';
            ac.Step := 0;
            ac.StepCount := MAX_PRIME-MIN_PRIME;
            for x := MIN_PRIME to MAX_PRIME do begin
              if (x and 1)=0 then continue;//skip evens
              ac.Step := x-MIN_PRIME;
              qi := TQueueItem_IsPrime.create;
              qi.in_n := x;
              GMQ.AddItem(qi);
              qi.autodestroy := true;
              qi.onFinish_Anon := ( procedure (qilocal: TQueueItem)
                                begin
                                  if (qilocal as TQueueItem_IsPrime).out_isPrime then
                                    inc(res);
                                end
              );

            end;
            GMQ.WaitForAllQueues;
          end
          ,
          procedure(result: ni)
          begin
            GMQ.WaitForAllQueues;
            tmEnd := gettimesince(tmStart);
            lblResult.caption := 'Found '+inttostr(res)+' primes in '+floatprecision(tmEnd/1000,3)+' seconds.';

          end,
          procedure(e: Exception)
          begin
            raise e;

          end
          , true, false
        );
  ac.SynchronizeFinish := true;
  ac.start;
  activecmd := ac;




end;

procedure TForm1.Button1Click(Sender: TObject);
var
  fbm: TFastBitmap;
  outfbm: TFastBitmap;
  jpg: TJPEGImage;
  bitmap: TBitmap;
begin
  //make a fast bitmap from the image component
  fbm := TFastBitmap.create;
//  fbm.FromPNG(image1.picture.bit);
  Debug.Log(image1.picture.graphic.ClassName);
  if image1.picture.graphic is TJPEGImage then begin
    bitmap := jpegToBitmap(image1.picture.graphic as TJpegImage, true);
    try
      fbm.FromBitmap(bitmap);
      image1.picture.assign(bitmap);
//      bitmap.assign(image1.picture);
//      fbm.AssignToPicture(image1.picture);
    finally
      bitmap.free;
    end;
  end else begin
    fbm.FromPNG(image1.picture.graphic as TPNGImage);
  end;


  //make an output fast bitmap
  outfbm := TFastBitmap.create;
  outfbm.Allocate(fbm.Width, fbm.Height);
  outfbm.New;
  self.activecmd := outfbm.IterateExternalSource_begin(fbm,
            procedure (source: TFastBitmap; dest: TFastBitmap; region: TRect; prog: PProgress)
            var
              x,y: ni;
            begin
              if prog <> nil then prog.stepcount := region.bottom-region.Top;
              for y := region.top to region.Bottom do begin
                if prog <> nil then prog.step := y-region.top;
                for x := region.Left to region.right do begin
                  dest.Canvas.Pixels[x,y] := source.Canvas.getaveragepixel(x,y,16,16);
                end;
              end;
            end
            ,
            TileNotify
  );



end;

procedure TForm1.btnCommandsClick(Sender: TObject);
var
  ac: TAnonymousCommand<ni>;
  res: ni;
  tmStart,tmEnd: ticker;
begin
  //
  res := 0;

  RefreshProcInfo;

  tmStart := getticker;

  ac := TAnonymousCommand<ni>.create(
          function: ni
          var
            x: ni;
            cmd: Tcommand_IsPrime;
          begin
            res := 0;
            ac.Status := 'Creating Queue Items';
            ac.Step := 0;
            ac.StepCount := MAX_PRIME-MIN_PRIME;
            for x := MIN_PRIME to MAX_PRIME do begin
              if (x and 1)=0 then continue;//skip evens
              ac.Step := x-MIN_PRIME;
              cmd := TCommand_IsPrime.create;
              cmd.in_n := x;
              cmd.FireForget := true;
              cmd.start;
              cmd.OnFinish_anon := ( procedure (cmd: TCommand)
                                begin
                                  if (cmd as TCommand_IsPrime).out_isPrime then
                                    inc(res);
                                end
              );

            end;
            while BGCmd.commandcount > 1 do
              sleep(1000);
//            BGCmd.WaitForAll(self);
          end
          ,
          procedure(result: ni)
          begin
            tmEnd := gettimesince(tmStart);
            lblResult2.caption := 'Found '+inttostr(res)+' primes in '+floatprecision(tmEnd/1000,3)+' seconds.';

          end,
          procedure(e: Exception)
          begin
            raise e;

          end
          , true, false
        );
  ac.SynchronizeFinish := true;
  ac.start;
  activecmd := ac;

end;

procedure TForm1.FormCreate(Sender: TObject);
var
  frm: TFramTotalDebug;
begin
  frm := TframTotalDebug.create(self);
  frm.parent := panFrameHost;
  frm.Align := alClient;

end;

procedure TForm1.lblResultClick(Sender: TObject);
begin
  RefreshProcInfo;
end;

procedure TForm1.RefreshProcInfo;
begin
  lblResult.caption := GetEnabledCPUCount().tostring+' enabled cpus.'+CRLF+
                       Getnumberofphysicalprocessors().tostring+' physical cpus.'+CRLF+
                       Getnumberoflogicalprocessors().tostring+' logical cpus.'+CRLF;

  lblResult2.caption := GetEnabledCPUCount().tostring+' enabled cpus.'+CRLF+
                       Getnumberofphysicalprocessors().tostring+' physical cpus.'+CRLF+
                       Getnumberoflogicalprocessors().tostring+' logical cpus.'+CRLF;

end;

procedure TForm1.TabSheet1ContextPopup(Sender: TObject; MousePos: TPoint;
  var Handled: Boolean);
begin
  btnQueues.enabled := activecmd = nil;
end;

procedure TForm1.TileNotify(src, dest: TFastBitmap; region: TRect;
  state: TTileState);
var
  tile: TFastBitmap;
  bm: TBitmap;
begin
  //
  if state = tsFinished then begin
    tile := TFastBitmap.create;
    tile.FromFAstBitmapRect(dest, region);
    bm := tile.tobitmap;
    image1.picture.Bitmap.Canvas.Draw(region.left, region.top, bm);
    //image1.picture.bitmap.canvas.Rectangle(region);
    bm.free;
    tile.free;
  end;


end;

procedure TForm1.tmCheckCommandTimer(Sender: TObject);
begin
  UpdateState;
  if activecmd <> nil then begin
//    if activecmd is Tcmd_FastBitmapIterate then begin
//      Tcmd_FastBitmapIterate(activecmd).dest.AssignToPicture(image1.picture);
//    end;

    if activecmd.IsComplete then begin
      activecmd.waitfor;

      if activecmd is Tcmd_FastBitmapIterate then begin
        Tcmd_FastBitmapIterate(activecmd).dest.AssignToPicture(image1.picture);
      end;

      activecmd.free;
      activecmd := nil;
    end;
  end;
end;

procedure TForm1.UpdateState;
begin
  Button1.Enabled := activecmd = nil;
  btnQueues.enabled := button1.enabled;
  btnCommands.enabled := button1.enabled;
end;

{ TQueueItem_IsPrime }

procedure TQueueItem_IsPrime.DoExecute;
begin
  inherited;
  out_IsPrime := CheckIsPrime(in_n, nil);
end;

{ Tcmd_CreatePrimeTestsUsingQueues }

function CheckIsPrime(n: int64; p: PProgress): boolean;
var
  x: ni;
  cx: ni;
begin
  result := true;
  cx := (n div 2);
  if assigned(p) then
    p.stepcount := cx;
  for x := 2 to cx do begin
    if (x and 1) = 0 then continue; //multiples of even numbers are also even, so skip anything without the low bit set
    //if no remainder from modulus operation
    if assigned(p) then
      p.step := x;
    if (n mod x) = 0 then begin

      //this is not prime
      result:= false;
      break;
    end;
  end;
end;


{ TCommand_IsPrime }

procedure TCommand_IsPrime.DoExecute;
begin
  inherited;
  out_IsPrime := CheckIsPrime(in_n, @self.progress);
end;

end.
