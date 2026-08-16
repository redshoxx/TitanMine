package com.deepdrill.game;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.*;
import android.os.*;
import android.view.*;
import java.text.DecimalFormat;
import java.util.*;

public class DrillGameView extends View {
    private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Random rng = new Random();
    private final SharedPreferences prefs;
    private final DecimalFormat df = new DecimalFormat("0.##");

    private long lastFrame = System.nanoTime();
    private long lastSave = System.currentTimeMillis();
    private boolean holding = false;
    private float touchX, touchY;
    private int tab = 0;

    private double cash, gems;
    private double depth;
    private int drillLevel, speedLevel, torqueLevel, coolingLevel, scannerLevel, offlineLevel;
    private double heat = 18;
    private double fuel = 100;
    private double combo = 1;
    private int prestige = 0;
    private double bestDepth = 0;
    private int crates = 0;
    private double totalCash = 0;
    private double boostSeconds = 0;
    private double overdriveSeconds = 0;

    private float drillAngle = 0;
    private float shake = 0;
    private float screenFlash = 0;
    private int milestonePulse = 0;

    private final ArrayList<Particle> particles = new ArrayList<>();
    private final ArrayList<FloatingText> floats = new ArrayList<>();

    private static class Particle {
        float x,y,vx,vy,life,size;
        int color;
        Particle(float x,float y,float vx,float vy,float life,float size,int color){this.x=x;this.y=y;this.vx=vx;this.vy=vy;this.life=life;this.size=size;this.color=color;}
    }
    private static class FloatingText {
        float x,y,life;
        String text;
        int color;
        FloatingText(float x,float y,String text,int color){this.x=x;this.y=y;this.text=text;this.color=color;this.life=1.25f;}
    }

    public DrillGameView(Context context) {
        super(context);
        setLayerType(View.LAYER_TYPE_HARDWARE, null);
        prefs = context.getSharedPreferences("deepdrill_save", Context.MODE_PRIVATE);
        load();
        stroke.setStyle(Paint.Style.STROKE);
        stroke.setStrokeCap(Paint.Cap.ROUND);
        setFocusable(true);
    }

    private void load() {
        cash = Double.longBitsToDouble(prefs.getLong("cash", Double.doubleToLongBits(420)));
        gems = Double.longBitsToDouble(prefs.getLong("gems", Double.doubleToLongBits(25)));
        depth = Double.longBitsToDouble(prefs.getLong("depth", Double.doubleToLongBits(0)));
        drillLevel = prefs.getInt("drill", 1);
        speedLevel = prefs.getInt("speed", 1);
        torqueLevel = prefs.getInt("torque", 1);
        coolingLevel = prefs.getInt("cool", 1);
        scannerLevel = prefs.getInt("scan", 1);
        offlineLevel = prefs.getInt("offline", 1);
        prestige = prefs.getInt("prestige", 0);
        bestDepth = Double.longBitsToDouble(prefs.getLong("best", Double.doubleToLongBits(depth)));
        totalCash = Double.longBitsToDouble(prefs.getLong("total", Double.doubleToLongBits(cash)));
        crates = prefs.getInt("crates",0);
        long savedAt = prefs.getLong("savedAt", System.currentTimeMillis());
        long away = Math.max(0, System.currentTimeMillis() - savedAt);
        double cappedSec = Math.min(away / 1000.0, offlineCapHours() * 3600.0);
        if (cappedSec > 10) {
            double earned = passiveCashPerSec() * cappedSec * .35;
            cash += earned;
            totalCash += earned;
            floats.add(new FloatingText(540, 380, "OFFLINE +" + fmt(earned), Color.rgb(255,205,74)));
        }
    }

    public void saveNow() {
        prefs.edit()
            .putLong("cash", Double.doubleToRawLongBits(cash))
            .putLong("gems", Double.doubleToRawLongBits(gems))
            .putLong("depth", Double.doubleToRawLongBits(depth))
            .putInt("drill",drillLevel).putInt("speed",speedLevel).putInt("torque",torqueLevel)
            .putInt("cool",coolingLevel).putInt("scan",scannerLevel).putInt("offline",offlineLevel)
            .putInt("prestige",prestige).putLong("best",Double.doubleToRawLongBits(bestDepth))
            .putLong("total",Double.doubleToRawLongBits(totalCash)).putInt("crates",crates)
            .putLong("savedAt",System.currentTimeMillis()).apply();
    }

    private double offlineCapHours(){ return 1.5 + offlineLevel * .5; }
    private double prestigeMultiplier(){ return 1.0 + prestige * .35; }
    private double drillPower(){ return (9 + drillLevel * 3.7) * Math.pow(1.045, drillLevel) * prestigeMultiplier(); }
    private double rpm(){ return 92 + speedLevel * 11; }
    private double torque(){ return 1.0 + torqueLevel * .14; }
    private double cooling(){ return 4.2 + coolingLevel * .48; }
    private double scannerBonus(){ return 1.0 + scannerLevel * .06; }
    private double passiveCashPerSec(){ return drillPower() * .24 * scannerBonus() * layerValue(depth); }
    private double cost(int which){
        int lv = which==0?drillLevel:which==1?speedLevel:which==2?torqueLevel:which==3?coolingLevel:which==4?scannerLevel:offlineLevel;
        double base = new double[]{110,145,175,210,260,360}[which];
        return base * Math.pow(1.31, lv-1);
    }

    @Override protected void onDraw(Canvas c) {
        super.onDraw(c);
        long now = System.nanoTime();
        float dt = Math.min(.035f, (now-lastFrame)/1_000_000_000f);
        lastFrame = now;
        update(dt);
        drawGame(c);
        postInvalidateOnAnimation();
    }

    private void update(float dt) {
        boolean drilling = heat < 99 && fuel > 0.2;
        double active = holding ? 2.7 * combo : 1.0;
        double boost = boostSeconds>0 ? 2.0 : 1.0;
        double over = overdriveSeconds>0 ? 3.0 : 1.0;
        double rate = drilling ? drillPower() * torque() * active * boost * over / (85 + depth * .035) : 0;
        double meters = rate * dt;
        depth += meters;
        bestDepth = Math.max(bestDepth, depth);
        double income = passiveCashPerSec() * dt * (holding?1.28:1.0) * boost * over;
        cash += income; totalCash += income;
        fuel = Math.max(0, fuel - dt * (holding?0.95:0.22) * (overdriveSeconds>0?1.6:1));
        fuel = Math.min(100, fuel + dt * (holding?0:0.16));
        heat += dt * (holding ? (8.5 + speedLevel*.035) : -cooling());
        if (overdriveSeconds>0) heat += dt*7;
        heat = Math.max(0, Math.min(100, heat));
        if (heat >= 99 && holding) {
            holding = false;
            floats.add(new FloatingText(getWidth()/2f, getHeight()*.67f, "OVERHEAT", Color.rgb(255,82,60)));
            vibrate(80);
        }
        if (boostSeconds>0) boostSeconds -= dt;
        if (overdriveSeconds>0) overdriveSeconds -= dt;
        combo += dt * (holding ? .52 : -1.35);
        combo = Math.max(1, Math.min(5, combo));
        drillAngle += dt * (float)(rpm() * .045 * (holding?1.7:1));
        shake *= Math.pow(.02, dt);
        screenFlash = Math.max(0, screenFlash-dt*2.2f);

        int oldMilestone = (int)((depth-meters)/250);
        int newMilestone = (int)(depth/250);
        if (newMilestone > oldMilestone) {
            gems += 4 + Math.min(16,newMilestone/2);
            crates++;
            milestonePulse=18;
            screenFlash=.5f;
            floats.add(new FloatingText(getWidth()/2f, getHeight()*.43f, "MILESTONE +GEMS", Color.rgb(196,98,255)));
            vibrate(45);
        }
        if (drilling && rng.nextFloat() < dt * (.55 + scannerLevel*.018)) {
            float x = getWidth()/2f + (rng.nextFloat()-.5f)*180;
            float y = getHeight()*.64f + rng.nextFloat()*110;
            spawnSparks(x,y, holding?5:2);
        }
        if (drilling && rng.nextFloat() < dt * .07 * scannerBonus()) {
            double bonus = passiveCashPerSec() * (6 + rng.nextInt(12));
            cash += bonus; totalCash += bonus;
            floats.add(new FloatingText(getWidth()/2f+120, getHeight()*.58f, "RARE ORE +"+fmt(bonus), Color.rgb(70,221,255)));
            screenFlash=.2f;
        }
        for (int i=particles.size()-1;i>=0;i--) {
            Particle q=particles.get(i); q.life-=dt; q.x+=q.vx*dt; q.y+=q.vy*dt; q.vy+=240*dt;
            if(q.life<=0) particles.remove(i);
        }
        for (int i=floats.size()-1;i>=0;i--) {
            FloatingText f=floats.get(i); f.life-=dt; f.y-=42*dt;
            if(f.life<=0) floats.remove(i);
        }
        if (System.currentTimeMillis()-lastSave > 9000) { saveNow(); lastSave=System.currentTimeMillis(); }
        if (milestonePulse>0) milestonePulse--;
    }

    private void drawGame(Canvas c) {
        int w=getWidth(), h=getHeight();
        drawBackground(c,w,h);
        drawHeader(c,w,h);
        if(tab==0) drawDrillScreen(c,w,h);
        else if(tab==1) drawUpgradeScreen(c,w,h);
        else if(tab==2) drawBoostScreen(c,w,h);
        else drawStatsScreen(c,w,h);
        drawBottomNav(c,w,h);
        drawParticles(c);
        drawFloating(c);
        if(screenFlash>0){p.setColor(Color.argb((int)(70*screenFlash),255,186,55));c.drawRect(0,0,w,h,p);}
    }

    private void drawBackground(Canvas c,int w,int h){
        p.setShader(new LinearGradient(0,0,0,h, Color.rgb(8,15,23), layerColor(depth), Shader.TileMode.CLAMP));
        c.drawRect(0,0,w,h,p);p.setShader(null);
        int top=(int)(h*.105), bottom=(int)(h*.875);
        int rock=darken(layerColor(depth),.46f);
        p.setColor(rock); c.drawRect(0,top,w,bottom,p);
        int seed=(int)(depth/40);
        Random rr=new Random(seed);
        for(int i=0;i<75;i++){
            float x=rr.nextFloat()*w, y=top+rr.nextFloat()*(bottom-top);
            float r=4+rr.nextFloat()*22;
            int cc = rr.nextBoolean()?lighten(rock,.16f):darken(rock,.18f);
            p.setColor(Color.argb(100,Color.red(cc),Color.green(cc),Color.blue(cc)));
            c.drawOval(x-r,y-r*.6f,x+r,y+r*.6f,p);
        }
        p.setShader(new LinearGradient(0,0,w,0, Color.argb(190,0,0,0),Color.TRANSPARENT,Shader.TileMode.MIRROR));
        c.drawRect(0,top,w,bottom,p);p.setShader(null);
    }

    private void drawHeader(Canvas c,int w,int h){
        float hh=h*.105f;
        p.setColor(Color.rgb(7,16,26));c.drawRect(0,0,w,hh,p);
        p.setColor(Color.rgb(25,43,60));c.drawRect(0,hh-3,w,hh,p);
        drawStatBox(c,18,18,w*.34f,hh-22,"CASH",fmt(cash),Color.rgb(255,190,42));
        drawStatBox(c,w*.36f,18,w*.22f,hh-22,"GEMS",fmt(gems),Color.rgb(193,77,255));
        drawStatBox(c,w*.60f,18,w*.18f,hh-22,"DEPTH",((int)depth)+"m",Color.rgb(72,189,255));
        drawStatBox(c,w*.80f,18,w*.18f,hh-22,"LAYER",layerName(depth),Color.rgb(255,132,37));
    }

    private void drawStatBox(Canvas c,float x,float y,float ww,float hh,String label,String value,int accent){
        round(c,x,y,x+ww,y+hh,16,Color.rgb(15,28,42));
        p.setColor(accent);c.drawRoundRect(x,y,x+7,y+hh,7,7,p);
        text(c,label,x+18,y+23,14,Color.rgb(135,157,178),false);
        text(c,value,x+18,y+49,22,Color.WHITE,true);
    }

    private void drawDrillScreen(Canvas c,int w,int h){
        float top=h*.115f, bottom=h*.86f;
        drawMilestones(c,w,h,top,bottom);
        float cx=w*.50f, shaftW=w*.38f;
        p.setShader(new LinearGradient(cx-shaftW/2,0,cx+shaftW/2,0, Color.rgb(12,17,22),Color.rgb(34,43,50),Shader.TileMode.MIRROR));
        c.drawRoundRect(cx-shaftW/2,top+20,cx+shaftW/2,bottom-20,24,24,p);p.setShader(null);
        p.setShader(new RadialGradient(cx,h*.60f,w*.30f,Color.argb(90,255,134,28),Color.TRANSPARENT,Shader.TileMode.CLAMP));
        c.drawCircle(cx,h*.60f,w*.30f,p);p.setShader(null);
        drawDrill(c,cx,top+72,bottom-95,w*.22f);
        miniMeter(c,18,top+90,w*.22f,68,"HEAT",heat/100.0,Color.rgb(255,88,55),((int)heat)+"%");
        miniMeter(c,18,top+168,w*.22f,68,"ENERGY",fuel/100.0,Color.rgb(81,208,255),((int)fuel)+"%");
        miniMeter(c,18,top+246,w*.22f,68,"COMBO",(combo-1)/4.0,Color.rgb(255,194,39),"x"+df.format(combo));
        miniInfo(c,w*.76f,top+90,w*.22f,72,"POWER",fmt(drillPower()),"DMG/s");
        miniInfo(c,w*.76f,top+172,w*.22f,72,"RPM",((int)rpm())+"","SPEED");
        miniInfo(c,w*.76f,top+254,w*.22f,72,"VALUE","x"+df.format(layerValue(depth)*scannerBonus()),"ORE");
        float by=bottom-88;
        boolean hot=heat>=99;
        int bc= hot?Color.rgb(123,44,40):(holding?Color.rgb(255,143,24):Color.rgb(28,139,218));
        round(c,w*.22f,by,w*.78f,by+72,22,bc);
        text(c,hot?"COOLING...":(holding?"DRILLING  x"+df.format(combo):"HOLD TO DRILL"),w*.50f,by+35,24,Color.WHITE,true,true);
        text(c,hot?"Wait for heat to drop":"Hold or tap to push deeper",w*.50f,by+58,13,Color.argb(210,255,255,255),false,true);
    }

    private void drawDrill(Canvas c,float cx,float top,float bottom,float dw){
        float sx = (float)(Math.sin(drillAngle*1.9)*shake*4);
        c.save(); c.translate(sx,0);
        p.setShader(new LinearGradient(cx-dw,0,cx+dw,0,Color.rgb(66,74,82),Color.rgb(14,19,24),Shader.TileMode.MIRROR));
        c.drawRoundRect(cx-dw*.85f,top,cx+dw*.85f,top+95,18,18,p); p.setShader(null);
        p.setColor(Color.rgb(241,152,32));c.drawRoundRect(cx-dw*.78f,top+16,cx+dw*.78f,top+30,7,7,p);
        c.drawRoundRect(cx-dw*.78f,top+65,cx+dw*.78f,top+79,7,7,p);
        float shaftTop=top+84, bitTop=bottom-170;
        p.setShader(new LinearGradient(cx-dw*.35f,0,cx+dw*.35f,0,Color.rgb(238,242,245),Color.rgb(44,51,58),Shader.TileMode.MIRROR));
        c.drawRoundRect(cx-dw*.34f,shaftTop,cx+dw*.34f,bitTop,12,12,p); p.setShader(null);
        for(int i=0;i<7;i++){
            float yy=shaftTop+28+i*(bitTop-shaftTop-30)/6f;
            float phase=(float)Math.sin(drillAngle+i*.8);
            p.setColor(Color.rgb(245,151,26));
            c.drawRoundRect(cx-dw*.43f,yy-7,cx+dw*.43f,yy+7,6,6,p);
            p.setColor(Color.argb(145,255,255,255));
            c.drawRect(cx+phase*dw*.18f-3,yy-20,cx+phase*dw*.18f+3,yy+20,p);
        }
        Path bit=new Path();
        bit.moveTo(cx-dw*.68f,bitTop);
        bit.lineTo(cx+dw*.68f,bitTop);
        bit.lineTo(cx+dw*.50f,bottom-38);
        bit.lineTo(cx,bottom);
        bit.lineTo(cx-dw*.50f,bottom-38);
        bit.close();
        p.setShader(new LinearGradient(cx-dw,0,cx+dw,0,Color.rgb(198,205,211),Color.rgb(44,47,52),Shader.TileMode.MIRROR));
        c.drawPath(bit,p);p.setShader(null);
        stroke.setStrokeWidth(10);stroke.setColor(Color.rgb(247,137,22));
        for(int i=0;i<5;i++){
            float yy=bitTop+18+i*24;
            float off=(float)Math.sin(drillAngle+i)*dw*.12f;
            c.drawLine(cx-dw*.48f,yy,cx+dw*.45f+off,yy+20,stroke);
        }
        p.setShader(new RadialGradient(cx,bottom-10,dw*.62f,Color.rgb(255,225,90),Color.argb(0,255,90,10),Shader.TileMode.CLAMP));
        c.drawCircle(cx,bottom-10,dw*.62f,p);p.setShader(null);
        c.restore();
    }

    private void drawMilestones(Canvas c,int w,int h,float top,float bottom){
        float x=w*.115f;
        stroke.setStrokeWidth(6);stroke.setColor(Color.rgb(78,90,101));
        c.drawLine(x,top+340,x,bottom-140,stroke);
        int current=(int)(depth/250);
        for(int i=-2;i<=2;i++){
            int m=(current+i)*250;
            if(m<0) continue;
            float yy=(float)(top+340 + ((m-depth)/500.0)*(bottom-top-520));
            if(yy<top+50||yy>bottom-85) continue;
            boolean passed=depth>=m;
            p.setColor(passed?Color.rgb(55,211,107):Color.rgb(31,43,54));c.drawCircle(x,yy,18,p);
            stroke.setStrokeWidth(3);stroke.setColor(passed?Color.rgb(163,255,191):Color.rgb(111,130,146));c.drawCircle(x,yy,18,stroke);
            text(c,m+"m",x,yy-28,14,passed?Color.rgb(114,236,148):Color.rgb(166,179,190),true,true);
            if(!passed && m==((current+1)*250)) {
                round(c,x-39,yy+24,x+39,yy+56,10,Color.rgb(85,42,116));
                text(c,"+"+(4+Math.min(16,m/500))+" G",x,yy+45,14,Color.WHITE,true,true);
            }
        }
    }

    private void miniMeter(Canvas c,float x,float y,float ww,float hh,String title,double frac,int color,String value){
        round(c,x,y,x+ww,y+hh,14,Color.argb(230,12,27,39));
        text(c,title,x+13,y+20,12,Color.rgb(146,165,180),true);
        text(c,value,x+13,y+43,20,Color.WHITE,true);
        p.setColor(Color.rgb(42,53,62));c.drawRoundRect(x+12,y+51,x+ww-12,y+60,5,5,p);
        p.setColor(color);c.drawRoundRect(x+12,y+51,(float)(x+12+(ww-24)*Math.max(0,Math.min(1,frac))),y+60,5,5,p);
    }
    private void miniInfo(Canvas c,float x,float y,float ww,float hh,String title,String value,String sub){
        round(c,x,y,x+ww,y+hh,14,Color.argb(230,12,27,39));
        text(c,title,x+12,y+19,11,Color.rgb(144,164,180),true);
        text(c,value,x+12,y+43,19,Color.WHITE,true);
        text(c,sub,x+12,y+60,10,Color.rgb(255,172,44),false);
    }

    private void drawUpgradeScreen(Canvas c,int w,int h){
        float top=h*.13f;
        text(c,"DRILL SYSTEMS",w*.06f,top+18,27,Color.WHITE,true);
        text(c,"Upgrade the machine. Every system changes drilling performance.",w*.06f,top+43,13,Color.rgb(150,169,183),false);
        String[] names={"DRILL HEAD","ROTATION SPEED","TORQUE MOTOR","LIQUID COOLING","ORE SCANNER","OFFLINE CORE"};
        String[] desc={"Raw drilling damage","Higher RPM and tap response","Pushes through harder layers","Removes heat faster","Finds valuable ore veins","Extends offline production"};
        int[] levels={drillLevel,speedLevel,torqueLevel,coolingLevel,scannerLevel,offlineLevel};
        int cols=2; float gap=16, margin=24, cardW=(w-margin*2-gap)/2f, cardH=132;
        for(int i=0;i<6;i++){
            int row=i/cols,col=i%cols;
            float x=margin+col*(cardW+gap), y=top+70+row*(cardH+14);
            boolean affordable=cash>=cost(i);
            round(c,x,y,x+cardW,y+cardH,18,Color.rgb(15,30,44));
            p.setColor(i==0?Color.rgb(255,154,29):Color.rgb(55,154,224));c.drawRoundRect(x,y,x+6,y+cardH,6,6,p);
            text(c,names[i],x+17,y+23,13,Color.rgb(188,204,217),true);
            text(c,"LV. "+levels[i],x+17,y+52,24,Color.WHITE,true);
            text(c,desc[i],x+17,y+75,11,Color.rgb(135,154,169),false);
            round(c,x+15,y+91,x+cardW-15,y+122,10,affordable?Color.rgb(44,161,87):Color.rgb(54,65,74));
            text(c,fmt(cost(i)),x+cardW/2,y+112,15,Color.WHITE,true,true);
        }
        if(bestDepth>=2500){
            float y=top+500;
            round(c,24,y,w-24,y+90,18,Color.rgb(63,35,78));
            text(c,"CORE RESET",45,y+30,18,Color.rgb(228,172,255),true);
            text(c,"Reset depth and upgrades for a permanent +35% output bonus.",45,y+53,12,Color.rgb(203,182,216),false);
            text(c,"PRESTIGE "+prestige,45,y+76,14,Color.WHITE,true);
            round(c,w-210,y+20,w-45,y+69,14,Color.rgb(139,63,194));
            text(c,"RESET",w-127,y+51,17,Color.WHITE,true,true);
        }
    }

    private void drawBoostScreen(Canvas c,int w,int h){
        float top=h*.13f;
        text(c,"BOOST BAY",w*.06f,top+18,27,Color.WHITE,true);
        text(c,"Short bursts for active sessions.",w*.06f,top+43,13,Color.rgb(150,169,183),false);
        drawBoostCard(c,w,top+78,"2x DEEP RUSH","Double drilling and income for 60 seconds.",8,boostSeconds,Color.rgb(41,137,214),0);
        drawBoostCard(c,w,top+210,"3x OVERDRIVE","Triple drilling for 25 seconds. Generates extra heat.",12,overdriveSeconds,Color.rgb(226,99,32),1);
        drawBoostCard(c,w,top+342,"EMERGENCY COOL","Instantly removes 65% heat.",5,0,Color.rgb(46,191,206),2);
        drawBoostCard(c,w,top+474,"CORE CELL","Refill energy to 100% immediately.",4,0,Color.rgb(133,96,218),3);
    }
    private void drawBoostCard(Canvas c,int w,float y,String name,String desc,int gemCost,double active,int color,int type){
        round(c,24,y,w-24,y+112,18,Color.rgb(15,30,44));
        p.setColor(color);c.drawCircle(64,y+56,28,p);
        text(c,type==0?"x2":type==1?"x3":type==2?"C":"E",64,y+63,22,Color.WHITE,true,true);
        text(c,name,105,y+30,18,Color.WHITE,true);
        text(c,desc,105,y+54,12,Color.rgb(145,164,179),false);
        if(active>0){
            text(c,((int)active)+"s ACTIVE",105,y+84,15,Color.rgb(95,233,143),true);
        } else {
            round(c,w-190,y+67,w-45,y+101,10,gems>=gemCost?color:Color.rgb(67,71,76));
            text(c,gemCost+" GEMS",w-117,y+90,14,Color.WHITE,true,true);
        }
    }

    private void drawStatsScreen(Canvas c,int w,int h){
        float top=h*.13f;
        text(c,"DRILL LOG",w*.06f,top+18,27,Color.WHITE,true);
        String[][] stats={
            {"BEST DEPTH",((int)bestDepth)+" m"}, {"CURRENT LAYER",layerName(depth)},
            {"TOTAL CASH",fmt(totalCash)}, {"PRESTIGE",String.valueOf(prestige)},
            {"CRATES FOUND",String.valueOf(crates)}, {"OFFLINE CAP",df.format(offlineCapHours())+" h"},
            {"DRILL POWER",fmt(drillPower())+"/s"}, {"ORE MULTIPLIER","x"+df.format(scannerBonus()*layerValue(depth))}
        };
        float y=top+65;
        for(String[] stat:stats){
            round(c,24,y,w-24,y+58,13,Color.rgb(15,29,42));
            text(c,stat[0],42,y+34,13,Color.rgb(145,164,179),true);
            text(c,stat[1],w-210,y+34,18,Color.WHITE,true);
            y+=68;
        }
    }

    private void drawBottomNav(Canvas c,int w,int h){
        float y=h*.875f;
        p.setColor(Color.rgb(7,15,24));c.drawRect(0,y,w,h,p);
        String[] labels={"DRILL","UPGRADES","BOOSTS","STATS"};
        String[] icons={"V","G","B","S"};
        float cell=w/4f;
        for(int i=0;i<4;i++){
            if(tab==i) round(c,i*cell+8,y+10,(i+1)*cell-8,h-12,15,Color.rgb(20,64,94));
            text(c,icons[i],i*cell+cell/2,y+38,23,tab==i?Color.rgb(82,196,255):Color.rgb(126,146,162),true,true);
            text(c,labels[i],i*cell+cell/2,y+67,11,tab==i?Color.WHITE:Color.rgb(126,146,162),true,true);
        }
    }

    private void drawParticles(Canvas c){
        for(Particle q:particles){
            int a=(int)(255*Math.min(1,q.life));
            p.setColor(Color.argb(a,Color.red(q.color),Color.green(q.color),Color.blue(q.color)));
            c.drawCircle(q.x,q.y,q.size,p);
        }
    }
    private void drawFloating(Canvas c){
        for(FloatingText f:floats){
            int a=(int)(255*Math.min(1,f.life));
            text(c,f.text,f.x,f.y,16,Color.argb(a,Color.red(f.color),Color.green(f.color),Color.blue(f.color)),true,true);
        }
    }

    private void spawnSparks(float x,float y,int n){
        for(int i=0;i<n;i++){
            float ang=(float)(rng.nextDouble()*Math.PI*2), sp=60+rng.nextFloat()*220;
            int col=rng.nextBoolean()?Color.rgb(255,182,43):Color.rgb(255,92,26);
            particles.add(new Particle(x,y,(float)Math.cos(ang)*sp,(float)Math.sin(ang)*sp-80,.3f+rng.nextFloat()*.5f,2+rng.nextFloat()*5,col));
        }
    }

    @Override public boolean onTouchEvent(MotionEvent e){
        touchX=e.getX();touchY=e.getY();
        float h=getHeight(), w=getWidth();
        if(e.getAction()==MotionEvent.ACTION_DOWN){
            if(touchY>h*.875f){
                tab=Math.min(3,(int)(touchX/(w/4f))); holding=false; invalidate(); return true;
            }
            if(tab==0){
                if(touchY>h*.60f && touchY<h*.86f){ holding=true; shake=1; combo=Math.min(5,combo+.16); spawnSparks(w/2f,h*.71f,8); vibrate(12); return true; }
            } else if(tab==1){ handleUpgradeTap(touchX,touchY); return true; }
            else if(tab==2){ handleBoostTap(touchX,touchY); return true; }
        } else if(e.getAction()==MotionEvent.ACTION_MOVE){
            if(tab==0 && touchY>h*.60f && touchY<h*.87f) holding=true;
        } else if(e.getAction()==MotionEvent.ACTION_UP || e.getAction()==MotionEvent.ACTION_CANCEL){
            holding=false;
        }
        return true;
    }

    private void handleUpgradeTap(float x,float y){
        int w=getWidth(), h=getHeight(); float top=h*.13f;
        float gap=16,margin=24,cardW=(w-margin*2-gap)/2f,cardH=132;
        for(int i=0;i<6;i++){
            int row=i/2,col=i%2;float xx=margin+col*(cardW+gap),yy=top+70+row*(cardH+14);
            if(x>=xx&&x<=xx+cardW&&y>=yy&&y<=yy+cardH){ buyUpgrade(i);return; }
        }
        if(bestDepth>=2500){float yy=top+500;if(x>w-230&&y>yy&&y<yy+95) doPrestige();}
    }
    private void buyUpgrade(int i){
        double co=cost(i); if(cash<co){floats.add(new FloatingText(getWidth()/2f,getHeight()*.65f,"NOT ENOUGH CASH",Color.rgb(255,90,70)));return;}
        cash-=co;
        switch(i){case 0:drillLevel++;break;case 1:speedLevel++;break;case 2:torqueLevel++;break;case 3:coolingLevel++;break;case 4:scannerLevel++;break;case 5:offlineLevel++;break;}
        floats.add(new FloatingText(getWidth()/2f,getHeight()*.62f,"UPGRADED",Color.rgb(86,232,133)));vibrate(18);saveNow();
    }
    private void doPrestige(){
        prestige++;cash=420;depth=0;drillLevel=speedLevel=torqueLevel=coolingLevel=scannerLevel=offlineLevel=1;heat=15;fuel=100;
        floats.add(new FloatingText(getWidth()/2f,getHeight()*.55f,"CORE RESET +35%",Color.rgb(222,152,255)));screenFlash=.8f;saveNow();
    }
    private void handleBoostTap(float x,float y){
        int w=getWidth(), h=getHeight();float top=h*.13f;
        float[] ys={top+78,top+210,top+342,top+474};int[] costs={8,12,5,4};
        for(int i=0;i<4;i++) if(y>=ys[i]&&y<=ys[i]+112){
            if(gems<costs[i]){floats.add(new FloatingText(w/2f,h*.65f,"NOT ENOUGH GEMS",Color.rgb(238,113,255)));return;}
            gems-=costs[i];
            if(i==0) boostSeconds=60; else if(i==1) overdriveSeconds=25; else if(i==2) heat=Math.max(0,heat-65); else fuel=100;
            screenFlash=.35f;vibrate(22);saveNow();return;
        }
    }

    private String layerName(double d){
        if(d<250)return "SOIL";if(d<650)return "SHALE";if(d<1200)return "GRANITE";if(d<2000)return "BASALT";if(d<3200)return "CRYSTAL";if(d<5000)return "MAGMA";return "CORE";
    }
    private double layerValue(double d){
        if(d<250)return 1;if(d<650)return 1.25;if(d<1200)return 1.7;if(d<2000)return 2.4;if(d<3200)return 3.6;if(d<5000)return 5.4;return 8.0;
    }
    private int layerColor(double d){
        if(d<250)return Color.rgb(70,48,31);if(d<650)return Color.rgb(55,52,55);if(d<1200)return Color.rgb(44,48,55);if(d<2000)return Color.rgb(35,38,43);if(d<3200)return Color.rgb(32,38,59);if(d<5000)return Color.rgb(61,31,28);return Color.rgb(37,18,22);
    }

    private void text(Canvas c,String s,float x,float y,float size,int color,boolean bold){text(c,s,x,y,size,color,bold,false);}
    private void text(Canvas c,String s,float x,float y,float size,int color,boolean bold,boolean center){
        p.setShader(null);p.setColor(color);p.setTextSize(size);p.setTypeface(bold?Typeface.create("sans",Typeface.BOLD):Typeface.create("sans",Typeface.NORMAL));
        p.setTextAlign(center?Paint.Align.CENTER:Paint.Align.LEFT);c.drawText(s,x,y,p);p.setTextAlign(Paint.Align.LEFT);
    }
    private void round(Canvas c,float l,float t,float r,float b,float rad,int color){p.setShader(null);p.setColor(color);c.drawRoundRect(l,t,r,b,rad,rad,p);}
    private int lighten(int color,float a){return Color.rgb((int)(Color.red(color)+(255-Color.red(color))*a),(int)(Color.green(color)+(255-Color.green(color))*a),(int)(Color.blue(color)+(255-Color.blue(color))*a));}
    private int darken(int color,float a){return Color.rgb((int)(Color.red(color)*(1-a)),(int)(Color.green(color)*(1-a)),(int)(Color.blue(color)*(1-a)));}
    private String fmt(double n){
        if(n<1000)return df.format(n);String[] u={"K","M","B","T","aa","ab","ac","ad","ae"};int i=-1;while(n>=1000&&i<u.length-1){n/=1000;i++;}return df.format(n)+u[i];
    }
    private void vibrate(long ms){
        try{Vibrator v=(Vibrator)getContext().getSystemService(Context.VIBRATOR_SERVICE);if(v!=null){if(Build.VERSION.SDK_INT>=26)v.vibrate(VibrationEffect.createOneShot(ms,90));else v.vibrate(ms);}}catch(Exception ignored){}
    }
}
