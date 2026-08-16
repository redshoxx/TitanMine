package com.deepdrill.game;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.*;
import android.os.*;
import android.view.*;
import java.text.DecimalFormat;
import java.util.*;

public final class DrillGameView extends View {
    private static final int TAB_DRILL = 0;
    private static final int TAB_UPGRADES = 1;
    private static final int TAB_BOOSTS = 2;
    private static final int TAB_STATS = 3;

    private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();
    private final Random rng = new Random();
    private final SharedPreferences prefs;
    private final DecimalFormat one = new DecimalFormat("0.0");
    private final DecimalFormat two = new DecimalFormat("0.##");

    private long lastFrame = System.nanoTime();
    private long lastSave = System.currentTimeMillis();

    private boolean holding;
    private boolean touchingArena;
    private int tab = TAB_DRILL;

    private double cash;
    private double gems;
    private double depth;
    private double bestDepth;
    private double totalCash;
    private int prestige;
    private int crates;

    private int drillLevel;
    private int speedLevel;
    private int torqueLevel;
    private int coolingLevel;
    private int scannerLevel;
    private int batteryLevel;

    private double heat = 12;
    private double energy = 100;
    private double combo = 1;
    private double boostSeconds;
    private double overdriveSeconds;

    private float drillAngle;
    private float worldScroll;
    private float shake;
    private float flash;
    private float pulse;
    private float holdPulse;

    private final ArrayList<Particle> particles = new ArrayList<>();
    private final ArrayList<FloatingText> floats = new ArrayList<>();

    private static final class Particle {
        float x,y,vx,vy,life,maxLife,size,spin;
        int color;
        boolean rock;
        Particle(float x,float y,float vx,float vy,float life,float size,int color,boolean rock) {
            this.x=x; this.y=y; this.vx=vx; this.vy=vy; this.life=life; this.maxLife=life;
            this.size=size; this.color=color; this.rock=rock; this.spin=(float)Math.random()*6.28f;
        }
    }

    private static final class FloatingText {
        float x,y,life,maxLife;
        final String text;
        final int color;
        FloatingText(float x,float y,String text,int color,float life) {
            this.x=x; this.y=y; this.text=text; this.color=color; this.life=life; this.maxLife=life;
        }
    }

    public DrillGameView(Context context) {
        super(context);
        setKeepScreenOn(true);
        setLayerType(View.LAYER_TYPE_HARDWARE, null);
        prefs = context.getSharedPreferences("deepdrill_save", Context.MODE_PRIVATE);
        stroke.setStyle(Paint.Style.STROKE);
        stroke.setStrokeCap(Paint.Cap.ROUND);
        load();
        setFocusable(true);
    }

    private void load() {
        cash = getDouble("cash", 460);
        gems = getDouble("gems", 25);
        depth = getDouble("depth", 0);
        bestDepth = getDouble("bestDepth", depth);
        totalCash = getDouble("totalCash", cash);
        prestige = prefs.getInt("prestige", 0);
        crates = prefs.getInt("crates", 0);
        drillLevel = prefs.getInt("drill", 1);
        speedLevel = prefs.getInt("speed", 1);
        torqueLevel = prefs.getInt("torque", 1);
        coolingLevel = prefs.getInt("cool", 1);
        scannerLevel = prefs.getInt("scan", 1);
        batteryLevel = prefs.getInt("battery", 1);

        long savedAt = prefs.getLong("savedAt", System.currentTimeMillis());
        double away = Math.max(0, System.currentTimeMillis() - savedAt) / 1000.0;
        away = Math.min(away, offlineCapHours() * 3600.0);
        if (away > 15) {
            double earned = passiveCashPerSecond() * away * 0.38;
            cash += earned;
            totalCash += earned;
            floats.add(new FloatingText(0,0,"OFFLINE  +" + fmt(earned), Color.rgb(255,205,74),2.6f));
        }
    }

    private double getDouble(String key,double def) {
        return Double.longBitsToDouble(prefs.getLong(key, Double.doubleToLongBits(def)));
    }

    public void saveNow() {
        prefs.edit()
                .putLong("cash", Double.doubleToRawLongBits(cash))
                .putLong("gems", Double.doubleToRawLongBits(gems))
                .putLong("depth", Double.doubleToRawLongBits(depth))
                .putLong("bestDepth", Double.doubleToRawLongBits(bestDepth))
                .putLong("totalCash", Double.doubleToRawLongBits(totalCash))
                .putInt("prestige", prestige)
                .putInt("crates", crates)
                .putInt("drill", drillLevel)
                .putInt("speed", speedLevel)
                .putInt("torque", torqueLevel)
                .putInt("cool", coolingLevel)
                .putInt("scan", scannerLevel)
                .putInt("battery", batteryLevel)
                .putLong("savedAt", System.currentTimeMillis())
                .apply();
    }

    private double offlineCapHours(){ return 2.0 + batteryLevel * 0.65; }
    private double prestigeMultiplier(){ return 1.0 + prestige * 0.42; }
    private double drillPower(){ return (14 + drillLevel * 4.6) * Math.pow(1.052, drillLevel) * prestigeMultiplier(); }
    private double rpm(){ return 110 + speedLevel * 15.5; }
    private double torque(){ return 1.0 + torqueLevel * 0.18; }
    private double cooling(){ return 4.7 + coolingLevel * 0.56; }
    private double scannerBonus(){ return 1.0 + scannerLevel * 0.075; }
    private double passiveCashPerSecond(){ return drillPower() * 0.26 * layerValue(depth) * scannerBonus(); }

    private double upgradeCost(int which) {
        int lv = levelFor(which);
        double[] base = {125,160,205,255,320,390};
        return base[which] * Math.pow(1.305, lv - 1);
    }

    private int levelFor(int which) {
        switch(which) {
            case 0: return drillLevel;
            case 1: return speedLevel;
            case 2: return torqueLevel;
            case 3: return coolingLevel;
            case 4: return scannerLevel;
            default: return batteryLevel;
        }
    }

    private void addLevel(int which) {
        switch(which) {
            case 0: drillLevel++; break;
            case 1: speedLevel++; break;
            case 2: torqueLevel++; break;
            case 3: coolingLevel++; break;
            case 4: scannerLevel++; break;
            default: batteryLevel++; break;
        }
    }

    @Override protected void onDraw(Canvas c) {
        long now = System.nanoTime();
        float dt = Math.min(0.035f, (now - lastFrame) / 1_000_000_000f);
        lastFrame = now;
        update(dt);
        render(c);
        postInvalidateOnAnimation();
    }

    private void update(float dt) {
        boolean canDrill = heat < 99.0 && energy > 0.15;
        double active = holding ? (2.6 * combo) : 1.0;
        double boost = boostSeconds > 0 ? 2.0 : 1.0;
        double overdrive = overdriveSeconds > 0 ? 3.0 : 1.0;
        double resistance = 84.0 + depth * 0.034 + layerHardness(depth) * 18.0;
        double meters = canDrill ? (drillPower() * torque() * active * boost * overdrive / resistance) * dt : 0;

        depth += meters;
        bestDepth = Math.max(bestDepth, depth);

        double income = passiveCashPerSecond() * dt * boost * overdrive * (holding ? 1.30 : 1.0);
        cash += income;
        totalCash += income;

        energy -= dt * (holding ? 1.05 : 0.26) * (overdriveSeconds > 0 ? 1.55 : 1.0);
        if (!holding) energy += dt * (0.18 + batteryLevel * 0.012);
        energy = clamp(energy,0,100);

        heat += dt * (holding ? (7.9 + speedLevel * 0.045) : -cooling());
        if (overdriveSeconds > 0) heat += dt * 6.8;
        heat = clamp(heat,0,100);

        if (heat >= 99 && holding) {
            holding = false;
            touchingArena = false;
            floats.add(new FloatingText(getWidth()*0.5f,getHeight()*0.58f,"OVERHEAT",Color.rgb(255,78,48),1.3f));
            vibrate(70);
            flash = 0.35f;
        }

        if (boostSeconds > 0) boostSeconds = Math.max(0, boostSeconds - dt);
        if (overdriveSeconds > 0) overdriveSeconds = Math.max(0, overdriveSeconds - dt);

        combo += dt * (holding ? 0.64 : -1.6);
        combo = clamp(combo,1,5);
        drillAngle += dt * (float)(rpm() * 0.055 * (holding ? 1.65 : 0.58));
        worldScroll += dt * (holding ? 72f : 20f);
        holdPulse += dt * (holding ? 7.5f : 2.2f);
        pulse += dt * 2.5f;
        shake *= Math.pow(0.025, dt);
        flash = Math.max(0, flash - dt * 1.8f);

        int oldMilestone = (int)((depth - meters) / 250.0);
        int newMilestone = (int)(depth / 250.0);
        if (newMilestone > oldMilestone) {
            int reward = 4 + Math.min(18,newMilestone/2);
            gems += reward;
            crates++;
            flash = 0.55f;
            shake = 14f;
            floats.add(new FloatingText(getWidth()*0.5f,getHeight()*0.38f,"MILESTONE  +" + reward + " GEMS",Color.rgb(192,92,255),1.8f));
            vibrate(55);
        }

        if (canDrill && holding && rng.nextFloat() < dt * 24f) {
            spawnDebris(getWidth()*0.5f,getHeight()*0.67f,1 + rng.nextInt(2));
        }
        if (canDrill && holding && rng.nextFloat() < dt * 12f) {
            spawnSparks(getWidth()*0.5f,getHeight()*0.67f,1 + rng.nextInt(3));
        }
        if (canDrill && rng.nextFloat() < dt * 0.055f * scannerBonus()) {
            double bonus = passiveCashPerSecond() * (10 + rng.nextInt(18));
            cash += bonus; totalCash += bonus;
            floats.add(new FloatingText(getWidth()*0.5f,getHeight()*0.52f,"RARE VEIN  +" + fmt(bonus),Color.rgb(74,224,255),1.6f));
            flash = Math.max(flash,0.18f);
        }

        for (int i=particles.size()-1;i>=0;i--) {
            Particle q=particles.get(i);
            q.life -= dt;
            q.x += q.vx*dt;
            q.y += q.vy*dt;
            q.vy += (q.rock ? 460f : 220f)*dt;
            q.spin += dt*5f;
            if(q.life<=0) particles.remove(i);
        }
        for (int i=floats.size()-1;i>=0;i--) {
            FloatingText f=floats.get(i);
            f.life -= dt;
            f.y -= 42f*dt;
            if(f.life<=0) floats.remove(i);
        }

        if (System.currentTimeMillis()-lastSave > 8000) {
            saveNow();
            lastSave = System.currentTimeMillis();
        }
    }

    private void render(Canvas c) {
        int w=getWidth(), h=getHeight();
        if(w<=0 || h<=0) return;
        float dx = shake > 0 ? (rng.nextFloat()-.5f)*shake : 0;
        float dy = shake > 0 ? (rng.nextFloat()-.5f)*shake*.45f : 0;
        c.save();
        c.translate(dx,dy);
        drawWorld(c,w,h);
        drawTopHud(c,w,h);
        if(tab==TAB_DRILL) drawDrillTab(c,w,h);
        else if(tab==TAB_UPGRADES) drawUpgrades(c,w,h);
        else if(tab==TAB_BOOSTS) drawBoosts(c,w,h);
        else drawStats(c,w,h);
        drawBottomBar(c,w,h);
        drawParticles(c);
        drawFloating(c,w,h);
        if(flash>0) {
            p.setColor(Color.argb((int)(80*flash),255,171,42));
            c.drawRect(0,0,w,h,p);
        }
        c.restore();
    }

    private void drawWorld(Canvas c,int w,int h) {
        int top=(int)(h*.095f);
        int bottom=(int)(h*.885f);
        int base=layerColor(depth);

        p.setShader(new LinearGradient(0,top,0,bottom,
                darken(base,.58f), darken(base,.28f), Shader.TileMode.CLAMP));
        c.drawRect(0,top,w,bottom,p); p.setShader(null);

        float band=150f;
        float off=worldScroll%band;
        for(float y=top-off; y<bottom; y+=band) {
            p.setColor(Color.argb(42,255,255,255));
            c.drawRect(0,y,w,y+2,p);
            p.setColor(Color.argb(38,0,0,0));
            c.drawRect(0,y+3,w,y+20,p);
        }

        Random rr=new Random((long)(depth/60)+17);
        for(int i=0;i<95;i++) {
            float x=rr.nextFloat()*w;
            float y=top + ((rr.nextFloat()*(bottom-top)+worldScroll*.35f)%(bottom-top));
            float r=5+rr.nextFloat()*19;
            int cc=rr.nextBoolean()?lighten(base,.10f):darken(base,.16f);
            p.setColor(Color.argb(95,Color.red(cc),Color.green(cc),Color.blue(cc)));
            c.drawOval(x-r,y-r*.52f,x+r,y+r*.52f,p);
        }

        float cx=w*.5f;
        float tunnelW=w*.48f;
        p.setShader(new LinearGradient(cx-tunnelW*.5f,0,cx+tunnelW*.5f,0,
                Color.rgb(4,6,8),Color.rgb(27,31,34),Shader.TileMode.MIRROR));
        c.drawRoundRect(cx-tunnelW*.5f,top+8,cx+tunnelW*.5f,bottom-10,34,34,p);
        p.setShader(null);

        p.setColor(Color.argb(90,0,0,0));
        c.drawRect(0,top,cx-tunnelW*.5f,bottom,p);
        c.drawRect(cx+tunnelW*.5f,top,w,bottom,p);

        stroke.setStrokeWidth(5);
        stroke.setColor(Color.argb(130,0,0,0));
        c.drawLine(cx-tunnelW*.5f,top,cx-tunnelW*.5f,bottom,stroke);
        c.drawLine(cx+tunnelW*.5f,top,cx+tunnelW*.5f,bottom,stroke);
        stroke.setStrokeWidth(2);
        stroke.setColor(Color.argb(65,150,170,184));
        c.drawLine(cx-tunnelW*.5f+7,top,cx-tunnelW*.5f+7,bottom,stroke);
        c.drawLine(cx+tunnelW*.5f-7,top,cx+tunnelW*.5f-7,bottom,stroke);

        p.setShader(new RadialGradient(cx,h*.63f,w*.30f,
                Color.argb(92,255,129,27),Color.TRANSPARENT,Shader.TileMode.CLAMP));
        c.drawCircle(cx,h*.63f,w*.31f,p); p.setShader(null);
    }

    private void drawTopHud(Canvas c,int w,int h) {
        float hh=h*.095f;
        p.setColor(Color.rgb(5,10,16));
        c.drawRect(0,0,w,hh,p);
        p.setColor(Color.rgb(35,49,61));
        c.drawRect(0,hh-2,w,hh,p);

        float gap=8;
        float boxW=(w-gap*5)/4f;
        hudBox(c,gap,9,boxW,hh-18,"CASH",fmt(cash),Color.rgb(255,190,44),0);
        hudBox(c,gap*2+boxW,9,boxW,hh-18,"GEMS",fmt(gems),Color.rgb(188,76,255),1);
        hudBox(c,gap*3+boxW*2,9,boxW,hh-18,"DEPTH",depthLabel(),Color.rgb(66,187,255),2);
        hudBox(c,gap*4+boxW*3,9,boxW,hh-18,"LAYER",layerName(depth),layerAccent(depth),3);
    }

    private void hudBox(Canvas c,float x,float y,float ww,float hh,String label,String value,int accent,int icon) {
        panel(c,x,y,x+ww,y+hh,14,Color.rgb(13,24,34),Color.rgb(33,49,62));
        p.setColor(accent);
        c.drawRoundRect(x,y,x+4,y+hh,4,4,p);
        drawHudIcon(c,x+18,y+hh*.5f,accent,icon);
        text(c,label,x+34,y+18,10,Color.rgb(137,155,170),false);
        text(c,value,x+34,y+39,18,Color.WHITE,true);
    }

    private void drawHudIcon(Canvas c,float x,float y,int color,int icon) {
        p.setColor(color);
        if(icon==0) {
            c.drawCircle(x,y,10,p);
            text(c,"$",x,y+4,12,Color.rgb(35,28,14),true,true);
        } else if(icon==1) {
            path.reset();
            path.moveTo(x,y-11); path.lineTo(x+9,y); path.lineTo(x,y+11); path.lineTo(x-9,y); path.close();
            c.drawPath(path,p);
        } else if(icon==2) {
            stroke.setStrokeWidth(3); stroke.setColor(color);
            c.drawLine(x,y-11,x,y+10,stroke);
            path.reset(); path.moveTo(x-5,y+5); path.lineTo(x,y+11); path.lineTo(x+5,y+5);
            c.drawPath(path,stroke);
        } else {
            c.drawCircle(x,y,9,p);
            p.setColor(Color.rgb(15,25,32)); c.drawCircle(x,y,4,p);
        }
    }

    private void drawDrillTab(Canvas c,int w,int h) {
        float top=h*.102f, bottom=h*.865f;
        float cx=w*.5f;
        drawDepthBadge(c,w,h,top);
        drawTelemetry(c,w,h,top);
        drawMilestoneRail(c,w,h,top,bottom);
        drawDrillRig(c,cx,top+58,bottom-92,w*.29f,h);
        drawHoldButton(c,w,h,bottom);
    }

    private void drawDepthBadge(Canvas c,int w,int h,float top) {
        float bw=w*.31f, bh=58;
        panel(c,w*.5f-bw*.5f,top+12,w*.5f+bw*.5f,top+12+bh,18,
                Color.rgb(11,20,29),Color.rgb(49,66,78));
        text(c,"CURRENT DEPTH",w*.5f,top+33,10,Color.rgb(145,163,178),false,true);
        text(c,depthLabel(),w*.5f,top+57,25,Color.WHITE,true,true);
    }

    private void drawTelemetry(Canvas c,int w,int h,float top) {
        float y=top+88;
        meterChip(c,12,y,w*.205f,61,"HEAT",(float)(heat/100.0),((int)heat)+"%",Color.rgb(255,86,50));
        meterChip(c,12,y+70,w*.205f,61,"ENERGY",(float)(energy/100.0),((int)energy)+"%",Color.rgb(64,205,255));
        meterChip(c,12,y+140,w*.205f,61,"COMBO",(float)((combo-1)/4.0),"x"+two.format(combo),Color.rgb(255,194,39));

        infoChip(c,w-w*.205f-12,y,w*.205f,61,"POWER",fmt(drillPower()),"DMG/S");
        infoChip(c,w-w*.205f-12,y+70,w*.205f,61,"RPM",String.valueOf((int)rpm()),"SPEED");
        infoChip(c,w-w*.205f-12,y+140,w*.205f,61,"ORE VALUE","x"+two.format(layerValue(depth)*scannerBonus()),"MULTI");
    }

    private void drawMilestoneRail(Canvas c,int w,int h,float top,float bottom) {
        float x=w*.095f;
        float railTop=top+270;
        float railBottom=bottom-74;
        stroke.setStrokeWidth(4); stroke.setColor(Color.rgb(66,79,91));
        c.drawLine(x,railTop,x,railBottom,stroke);

        int current=(int)(depth/250.0);
        for(int i=0;i<3;i++) {
            int milestone=(current+i+1)*250;
            float rel=(float)((milestone-depth)/750.0);
            float y=railTop + rel*(railBottom-railTop);
            if(y<railTop-20 || y>railBottom+20) continue;
            int accent=i==0?Color.rgb(186,79,255):Color.rgb(74,105,132);
            p.setColor(accent); c.drawCircle(x,y,12,p);
            p.setColor(Color.rgb(10,18,26)); c.drawCircle(x,y,7,p);
            text(c,milestone+"m",x,y-19,10,Color.rgb(185,197,207),false,true);
            if(i==0) {
                round(c,x-25,y+18,x+25,y+40,8,Color.rgb(91,36,123));
                text(c,"+"+(4+Math.min(18,(current+1)/2))+"G",x,y+33,10,Color.WHITE,true,true);
            }
        }
    }

    private void drawDrillRig(Canvas c,float cx,float top,float bottom,float bodyW,int h) {
        float rigTop=top;
        float tipY=bottom;
        float bodyTop=rigTop+58;
        float bodyBottom=tipY-96;
        float hw=bodyW*1.35f;
        panel(c,cx-hw*.5f,rigTop,cx+hw*.5f,rigTop+72,18,
                Color.rgb(31,38,43),Color.rgb(83,94,101));
        p.setShader(new LinearGradient(cx-hw*.5f,0,cx+hw*.5f,0,
                Color.rgb(101,68,27),Color.rgb(252,155,34),Shader.TileMode.MIRROR));
        c.drawRoundRect(cx-hw*.48f,rigTop+8,cx+hw*.48f,rigTop+25,8,8,p);
        p.setShader(null);
        p.setColor(Color.rgb(12,17,20));
        c.drawRect(cx-hw*.36f,rigTop+28,cx+hw*.36f,rigTop+61,p);
        p.setColor(Color.rgb(224,144,35));
        for(int i=-2;i<=2;i++) c.drawCircle(cx+i*hw*.15f,rigTop+44,5,p);

        p.setShader(new LinearGradient(cx-bodyW*.20f,0,cx+bodyW*.20f,0,
                new int[]{Color.rgb(33,39,43),Color.rgb(224,231,235),Color.rgb(83,91,97),Color.rgb(19,23,26)},
                null,Shader.TileMode.CLAMP));
        c.drawRoundRect(cx-bodyW*.20f,bodyTop,cx+bodyW*.20f,bodyBottom,14,14,p);
        p.setShader(null);

        for(int i=0;i<4;i++) {
            float y=bodyTop+28+i*(bodyBottom-bodyTop-60)/3f;
            p.setShader(new LinearGradient(cx-bodyW*.32f,0,cx+bodyW*.32f,0,
                    Color.rgb(75,83,89),Color.rgb(232,152,39),Shader.TileMode.MIRROR));
            c.drawRoundRect(cx-bodyW*.31f,y,cx+bodyW*.31f,y+13,5,5,p);
            p.setShader(null);
            p.setColor(Color.rgb(20,24,27));
            c.drawRect(cx-bodyW*.16f,y+3,cx+bodyW*.16f,y+10,p);
        }

        float bitTop=bodyBottom-12;
        float bitBottom=tipY-25;
        float taperTop=bodyW*.36f;
        float taperBottom=bodyW*.10f;

        path.reset();
        path.moveTo(cx-taperTop,bitTop);
        path.lineTo(cx+taperTop,bitTop);
        path.lineTo(cx+taperBottom,bitBottom);
        path.lineTo(cx,tipY);
        path.lineTo(cx-taperBottom,bitBottom);
        path.close();
        p.setShader(new LinearGradient(cx-taperTop,0,cx+taperTop,0,
                new int[]{Color.rgb(34,40,44),Color.rgb(152,163,170),Color.rgb(51,58,62),Color.rgb(19,23,25)},
                null,Shader.TileMode.CLAMP));
        c.drawPath(path,p); p.setShader(null);

        float helixSpan=bitBottom-bitTop;
        stroke.setStrokeCap(Paint.Cap.ROUND);
        for(int i=0;i<7;i++) {
            float phase=(drillAngle*22f + i*34f)%34f;
            float y=bitTop + (i/6f)*helixSpan;
            float t=(y-bitTop)/Math.max(1,helixSpan);
            float half=lerp(taperTop,taperBottom,t);
            path.reset();
            path.moveTo(cx-half,y-9);
            path.cubicTo(cx-half*.25f,y-18-phase*.05f,cx+half*.25f,y+14,cx+half,y+5);
            stroke.setStrokeWidth(10);
            stroke.setColor(Color.rgb(42,47,50));
            c.drawPath(path,stroke);
            stroke.setStrokeWidth(5);
            stroke.setColor(Color.rgb(255,147,34));
            c.drawPath(path,stroke);
            stroke.setStrokeWidth(1.5f);
            stroke.setColor(Color.argb(180,255,222,168));
            c.drawPath(path,stroke);
        }

        float glow=holding?(0.72f+0.22f*(float)Math.sin(holdPulse)):0.28f;
        p.setShader(new RadialGradient(cx,tipY,bodyW*.65f,
                Color.argb((int)(125*glow),255,112,24),Color.TRANSPARENT,Shader.TileMode.CLAMP));
        c.drawCircle(cx,tipY,bodyW*.65f,p); p.setShader(null);

        for(int i=-2;i<=2;i++) {
            float tx=cx+i*bodyW*.085f;
            path.reset();
            path.moveTo(tx-8,bitBottom-2);
            path.lineTo(tx+8,bitBottom-2);
            path.lineTo(tx,tipY-(Math.abs(i)*4));
            path.close();
            p.setColor(i==0?Color.rgb(255,176,53):Color.rgb(176,113,40));
            c.drawPath(path,p);
        }

        if(holding) {
            stroke.setStrokeWidth(2);
            stroke.setColor(Color.argb(100,255,180,80));
            float a=8+(float)Math.sin(holdPulse)*4;
            c.drawLine(cx-bodyW*.45f,tipY-a,cx-bodyW*.62f,tipY-a-10,stroke);
            c.drawLine(cx+bodyW*.45f,tipY-a,cx+bodyW*.62f,tipY-a-10,stroke);
        }
    }

    private void drawHoldButton(Canvas c,int w,int h,float bottom) {
        float x=w*.245f, ww=w*.51f, y=bottom-58, hh=58;
        boolean hot=heat>=99;
        int base=hot?Color.rgb(91,38,34):(holding?Color.rgb(238,126,25):Color.rgb(21,127,203));
        int border=hot?Color.rgb(160,70,59):(holding?Color.rgb(255,190,66):Color.rgb(74,182,246));
        panel(c,x,y,x+ww,y+hh,18,base,border);
        float glow=(float)(0.5+0.5*Math.sin(holdPulse));
        if(holding) {
            stroke.setStrokeWidth(3+glow*2); stroke.setColor(Color.argb(150,255,204,100));
            c.drawRoundRect(x-3,y-3,x+ww+3,y+hh+3,21,21,stroke);
        }
        text(c,hot?"COOLING SYSTEM":holding?"DRILLING  •  x"+two.format(combo):"PRESS & HOLD",x+ww*.5f,y+27,18,Color.WHITE,true,true);
        text(c,hot?"Heat must drop below 85%":"Push the drill deeper",x+ww*.5f,y+46,10,Color.argb(220,255,255,255),false,true);
    }

    private void drawUpgrades(Canvas c,int w,int h) {
        float top=h*.112f, bottom=h*.855f;
        title(c,w,top,"DRILL SYSTEMS","Upgrade the machine — every part changes your run");
        String[] names={"DRILL HEAD","MOTOR RPM","TORQUE DRIVE","COOLING","ORE SCANNER","BATTERY"};
        String[] desc={"Break harder layers","Faster rotation","More force per tick","Lower heat","More valuable veins","Longer offline income"};
        int[] accent={Color.rgb(255,152,38),Color.rgb(61,187,255),Color.rgb(255,198,52),Color.rgb(76,219,215),Color.rgb(174,87,255),Color.rgb(85,221,121)};
        for(int i=0;i<6;i++) {
            float row=i/2;
            float col=i%2;
            float gap=10;
            float cw=(w-34-gap)/2f;
            float ch=(bottom-(top+68)-20)/3f;
            float x=12+col*(cw+gap);
            float y=top+64+row*(ch+8);
            upgradeCard(c,x,y,cw,ch,i,names[i],desc[i],accent[i]);
        }
    }

    private void upgradeCard(Canvas c,float x,float y,float ww,float hh,int idx,String name,String desc,int accent) {
        panel(c,x,y,x+ww,y+hh,16,Color.rgb(12,22,31),Color.rgb(45,60,72));
        drawUpgradeIcon(c,x+33,y+34,accent,idx);
        text(c,name,x+61,y+25,13,Color.WHITE,true);
        text(c,"LV. "+levelFor(idx),x+61,y+45,11,accent,true);
        text(c,desc,x+16,y+70,10,Color.rgb(156,174,188),false);
        double cost=upgradeCost(idx);
        boolean afford=cash>=cost;
        float by=y+hh-45;
        panel(c,x+12,by,x+ww-12,by+34,10,afford?Color.rgb(45,144,71):Color.rgb(50,58,64),afford?Color.rgb(82,205,107):Color.rgb(83,92,99));
        text(c,afford?"UPGRADE  "+fmt(cost):"NEED  "+fmt(cost),(x+x+ww)*.5f,by+22,12,Color.WHITE,true,true);
    }

    private void drawUpgradeIcon(Canvas c,float x,float y,int accent,int idx) {
        p.setColor(Color.argb(35,Color.red(accent),Color.green(accent),Color.blue(accent)));
        c.drawCircle(x,y,23,p);
        stroke.setStrokeWidth(3); stroke.setColor(accent);
        if(idx==0) {
            path.reset(); path.moveTo(x,y-16); path.lineTo(x+12,y-2); path.lineTo(x+6,y+15); path.lineTo(x-6,y+15); path.lineTo(x-12,y-2); path.close();
            c.drawPath(path,stroke);
        } else if(idx==1) {
            c.drawCircle(x,y,14,stroke); c.drawLine(x,y,x+10,y-7,stroke);
        } else if(idx==2) {
            c.drawRect(x-14,y-8,x+14,y+8,stroke); c.drawCircle(x-7,y,3,stroke); c.drawCircle(x+7,y,3,stroke);
        } else if(idx==3) {
            c.drawCircle(x,y,14,stroke); c.drawLine(x-12,y,x+12,y,stroke); c.drawLine(x,y-12,x,y+12,stroke);
        } else if(idx==4) {
            c.drawCircle(x,y,15,stroke); c.drawCircle(x,y,6,stroke); c.drawLine(x-18,y,x+18,y,stroke); c.drawLine(x,y-18,x,y+18,stroke);
        } else {
            c.drawRoundRect(x-13,y-16,x+13,y+16,5,5,stroke); c.drawRect(x-4,y-20,x+4,y-16,stroke);
        }
    }

    private void drawBoosts(Canvas c,int w,int h) {
        float top=h*.112f;
        title(c,w,top,"BOOST BAY","Use gems for short high-intensity drilling runs");
        boostCard(c,w,top+80,"2× POWER","Double drill output for 5 minutes",10,Color.rgb(61,183,255),0);
        boostCard(c,w,top+190,"OVERDRIVE","3× output, more heat for 60 seconds",18,Color.rgb(255,126,36),1);
        boostCard(c,w,top+300,"CRATE SCANNER","Open one stored milestone crate",0,Color.rgb(185,82,255),2);

        if(boostSeconds>0) activeBoostStrip(c,w,top+420,"2× POWER",boostSeconds,300,Color.rgb(61,183,255));
        if(overdriveSeconds>0) activeBoostStrip(c,w,top+485,"OVERDRIVE",overdriveSeconds,60,Color.rgb(255,126,36));
    }

    private void boostCard(Canvas c,int w,float y,String name,String desc,int price,int accent,int type) {
        float x=18, ww=w-36, hh=92;
        panel(c,x,y,x+ww,y+hh,18,Color.rgb(12,22,31),Color.rgb(46,61,72));
        p.setColor(Color.argb(45,Color.red(accent),Color.green(accent),Color.blue(accent)));
        c.drawCircle(x+48,y+46,31,p);
        p.setColor(accent);
        if(type==0) {
            path.reset(); path.moveTo(x+45,y+19); path.lineTo(x+30,y+48); path.lineTo(x+44,y+48); path.lineTo(x+37,y+73); path.lineTo(x+65,y+38); path.lineTo(x+50,y+38); path.close(); c.drawPath(path,p);
        } else if(type==1) {
            c.drawCircle(x+48,y+46,18,p); p.setColor(Color.rgb(26,30,33)); c.drawCircle(x+48,y+46,8,p);
        } else {
            c.drawRect(x+31,y+33,x+65,y+60,p); c.drawRect(x+37,y+27,x+59,y+34,p);
        }
        text(c,name,x+91,y+32,17,Color.WHITE,true);
        text(c,desc,x+91,y+55,11,Color.rgb(156,174,188),false);
        String btn=type==2?(crates>0?"OPEN  •  "+crates+" CRATES":"NO CRATES"):(price+" GEMS");
        panel(c,x+ww-132,y+20,x+ww-14,y+70,13,Color.rgb(49,61,71),accent);
        text(c,btn,x+ww-73,y+50,11,Color.WHITE,true,true);
    }

    private void activeBoostStrip(Canvas c,int w,float y,String name,double seconds,double max,int accent) {
        panel(c,18,y,w-18,y+54,14,Color.rgb(12,22,31),accent);
        text(c,name,34,y+22,12,Color.WHITE,true);
        text(c,(int)seconds+"s",w-34,y+22,12,accent,true,true);
        float pct=(float)(seconds/max);
        round(c,34,y+34,w-34,y+42,4,Color.rgb(35,48,58));
        round(c,34,y+34,34+(w-68)*pct,y+42,4,accent);
    }

    private void drawStats(Canvas c,int w,int h) {
        float top=h*.112f;
        title(c,w,top,"DRILL LOG","Your machine history and permanent progression");
        float y=top+76;
        statRow(c,w,y,"BEST DEPTH",bestDepth<1000?((int)bestDepth)+" m":one.format(bestDepth/1000.0)+" km",Color.rgb(66,187,255));
        statRow(c,w,y+72,"TOTAL CASH",fmt(totalCash),Color.rgb(255,190,44));
        statRow(c,w,y+144,"MILESTONE CRATES",String.valueOf(crates),Color.rgb(184,79,255));
        statRow(c,w,y+216,"CORE PRESTIGE",String.valueOf(prestige),Color.rgb(255,126,36));
        statRow(c,w,y+288,"OFFLINE CAP",one.format(offlineCapHours())+" h",Color.rgb(83,219,124));

        float py=y+382;
        boolean ready=bestDepth>=10000;
        panel(c,18,py,w-18,py+104,18,Color.rgb(16,24,31),ready?Color.rgb(255,151,37):Color.rgb(74,84,92));
        text(c,"CORE REBUILD",36,py+29,17,Color.WHITE,true);
        text(c,"Reset depth and upgrades. Permanent +42% output.",36,py+52,11,Color.rgb(161,177,189),false);
        text(c,ready?"READY — TAP TO PRESTIGE":"UNLOCKS AT 10 km",36,py+82,13,ready?Color.rgb(255,177,52):Color.rgb(129,143,153),true);
    }

    private void statRow(Canvas c,int w,float y,String label,String value,int accent) {
        panel(c,18,y,w-18,y+58,15,Color.rgb(12,22,31),Color.rgb(43,57,68));
        p.setColor(accent); c.drawRoundRect(18,y,23,y+58,5,5,p);
        text(c,label,40,y+23,11,Color.rgb(147,165,179),false);
        text(c,value,w-40,y+35,20,Color.WHITE,true,true);
    }

    private void drawBottomBar(Canvas c,int w,int h) {
        float top=h*.885f;
        p.setColor(Color.rgb(5,11,17)); c.drawRect(0,top,w,h,p);
        p.setColor(Color.rgb(33,48,60)); c.drawRect(0,top,w,top+2,p);
        String[] labels={"DRILL","UPGRADES","BOOSTS","STATS"};
        for(int i=0;i<4;i++) {
            float x0=i*w/4f, x1=(i+1)*w/4f, cx=(x0+x1)/2f;
            boolean active=tab==i;
            if(active) {
                p.setShader(new LinearGradient(0,top,0,h,Color.rgb(25,78,108),Color.rgb(10,29,43),Shader.TileMode.CLAMP));
                c.drawRoundRect(x0+5,top+6,x1-5,h-6,16,16,p); p.setShader(null);
                p.setColor(Color.rgb(62,189,255)); c.drawRect(x0+20,top+6,x1-20,top+9,p);
            }
            int ic=active?Color.rgb(70,198,255):Color.rgb(117,136,151);
            drawNavIcon(c,cx,top+25,ic,i);
            text(c,labels[i],cx,top+56,10,active?Color.WHITE:Color.rgb(129,146,158),active,true);
        }
    }

    private void drawNavIcon(Canvas c,float x,float y,int color,int idx) {
        stroke.setStyle(Paint.Style.STROKE); stroke.setStrokeWidth(3); stroke.setColor(color);
        if(idx==0) {
            path.reset(); path.moveTo(x,y-14); path.lineTo(x+10,y-2); path.lineTo(x+5,y+13); path.lineTo(x-5,y+13); path.lineTo(x-10,y-2); path.close(); c.drawPath(path,stroke);
        } else if(idx==1) {
            c.drawCircle(x,y,12,stroke); c.drawLine(x-17,y,x+17,y,stroke); c.drawLine(x,y-17,x,y+17,stroke);
        } else if(idx==2) {
            path.reset(); path.moveTo(x+2,y-16); path.lineTo(x-9,y+2); path.lineTo(x,y+2); path.lineTo(x-4,y+16); path.lineTo(x+12,y-5); path.lineTo(x+3,y-5); path.close(); c.drawPath(path,stroke);
        } else {
            c.drawRect(x-14,y-12,x+14,y+12,stroke); c.drawLine(x-8,y+6,x-8,y-2,stroke); c.drawLine(x,y+6,x,y-8,stroke); c.drawLine(x+8,y+6,x+8,y-5,stroke);
        }
    }

    private void title(Canvas c,int w,float y,String name,String sub) {
        text(c,name,18,y+22,22,Color.WHITE,true);
        text(c,sub,18,y+44,11,Color.rgb(146,163,176),false);
        p.setColor(Color.rgb(43,57,68)); c.drawRect(18,y+55,w-18,y+57,p);
    }

    private void meterChip(Canvas c,float x,float y,float ww,float hh,String label,float pct,String value,int accent) {
        panel(c,x,y,x+ww,y+hh,13,Color.rgb(11,21,30),Color.rgb(42,57,68));
        text(c,label,x+12,y+18,9,Color.rgb(136,155,170),true);
        text(c,value,x+12,y+37,16,Color.WHITE,true);
        round(c,x+12,y+46,x+ww-12,y+53,4,Color.rgb(33,46,56));
        round(c,x+12,y+46,x+12+(ww-24)*clampf(pct,0,1),y+53,4,accent);
    }

    private void infoChip(Canvas c,float x,float y,float ww,float hh,String label,String value,String unit) {
        panel(c,x,y,x+ww,y+hh,13,Color.rgb(11,21,30),Color.rgb(42,57,68));
        text(c,label,x+12,y+18,9,Color.rgb(136,155,170),true);
        text(c,value,x+12,y+39,17,Color.WHITE,true);
        text(c,unit,x+12,y+54,8,Color.rgb(255,173,50),true);
    }

    private void panel(Canvas c,float l,float t,float r,float b,float radius,int fill,int border) {
        p.setStyle(Paint.Style.FILL);
        p.setColor(fill); c.drawRoundRect(l,t,r,b,radius,radius,p);
        stroke.setStyle(Paint.Style.STROKE); stroke.setStrokeWidth(1.5f); stroke.setColor(border);
        c.drawRoundRect(l+.75f,t+.75f,r-.75f,b-.75f,radius,radius,stroke);
        p.setColor(Color.argb(26,255,255,255));
        c.drawRoundRect(l+2,t+2,r-2,t+4,radius,radius,p);
    }

    private void round(Canvas c,float l,float t,float r,float b,float radius,int color) {
        p.setShader(null); p.setStyle(Paint.Style.FILL); p.setColor(color); c.drawRoundRect(l,t,r,b,radius,radius,p);
    }

    private void text(Canvas c,String s,float x,float y,float size,int color,boolean bold) {
        text(c,s,x,y,size,color,bold,false);
    }

    private void text(Canvas c,String s,float x,float y,float size,int color,boolean bold,boolean center) {
        p.setShader(null); p.setStyle(Paint.Style.FILL); p.setColor(color); p.setTextSize(size); p.setTypeface(bold?Typeface.create("sans-serif",Typeface.BOLD):Typeface.create("sans-serif",Typeface.NORMAL));
        p.setTextAlign(center?Paint.Align.CENTER:Paint.Align.LEFT);
        c.drawText(s,x,y,p);
    }

    private void spawnSparks(float x,float y,int count) {
        for(int i=0;i<count;i++) {
            float a=(float)(Math.PI + (rng.nextFloat()-.5f)*2.2);
            float s=180+rng.nextFloat()*480;
            particles.add(new Particle(x+(rng.nextFloat()-.5f)*50,y-12,(float)Math.cos(a)*s,(float)Math.sin(a)*s,0.35f+rng.nextFloat()*.35f,2+rng.nextFloat()*3,Color.rgb(255,168+rng.nextInt(70),38),false));
        }
    }

    private void spawnDebris(float x,float y,int count) {
        int base=lighten(layerColor(depth),.14f);
        for(int i=0;i<count;i++) {
            float a=(float)(-Math.PI/2 + (rng.nextFloat()-.5f)*2.7);
            float s=90+rng.nextFloat()*260;
            particles.add(new Particle(x+(rng.nextFloat()-.5f)*80,y,(float)Math.cos(a)*s,(float)Math.sin(a)*s,0.6f+rng.nextFloat()*.55f,5+rng.nextFloat()*9,base,true));
        }
    }

    private void drawParticles(Canvas c) {
        for(Particle q:particles) {
            float alpha=clampf(q.life/q.maxLife,0,1);
            int a=(int)(255*alpha);
            if(q.rock) {
                c.save(); c.rotate(q.spin*57.3f,q.x,q.y);
                p.setColor(Color.argb(a,Color.red(q.color),Color.green(q.color),Color.blue(q.color)));
                c.drawRect(q.x-q.size,q.y-q.size*.55f,q.x+q.size,q.y+q.size*.55f,p);
                c.restore();
            } else {
                stroke.setStrokeWidth(Math.max(1,q.size));
                stroke.setColor(Color.argb(a,Color.red(q.color),Color.green(q.color),Color.blue(q.color)));
                c.drawLine(q.x,q.y,q.x-q.vx*.025f,q.y-q.vy*.025f,stroke);
            }
        }
    }

    private void drawFloating(Canvas c,int w,int h) {
        for(FloatingText f:floats) {
            if(f.x==0 && f.y==0){ f.x=w*.5f; f.y=h*.18f; }
            int a=(int)(255*clampf(f.life/f.maxLife,0,1));
            int col=Color.argb(a,Color.red(f.color),Color.green(f.color),Color.blue(f.color));
            text(c,f.text,f.x,f.y,17,col,true,true);
        }
    }

    @Override public boolean onTouchEvent(android.view.MotionEvent e) {
        float x=e.getX(), y=e.getY();
        int h=getHeight(), w=getWidth();

        if(e.getAction()==MotionEvent.ACTION_DOWN) {
            if(y>h*.885f) {
                int newTab=Math.min(3,(int)(x/(w/4f)));
                tab=newTab;
                holding=false; touchingArena=false;
                vibrate(18);
                invalidate();
                return true;
            }

            if(tab==TAB_DRILL && y>h*.16f && y<h*.865f) {
                holding=heat<99 && energy>0.15;
                touchingArena=holding;
                shake=holding?5f:0;
                if(holding) vibrate(16);
                invalidate();
                return true;
            }

            if(tab==TAB_UPGRADES) {
                handleUpgradeTap(x,y,w,h);
                return true;
            }

            if(tab==TAB_BOOSTS) {
                handleBoostTap(x,y,w,h);
                return true;
            }

            if(tab==TAB_STATS && y>h*.30f && y<h*.82f) {
                tryPrestige();
                return true;
            }
        } else if(e.getAction()==MotionEvent.ACTION_UP || e.getAction()==MotionEvent.ACTION_CANCEL) {
            if(touchingArena) {
                holding=false;
                touchingArena=false;
                shake=0;
                performClick();
                return true;
            }
        }
        return true;
    }

    private void handleUpgradeTap(float x,float y,int w,int h) {
        float top=h*.112f, bottom=h*.855f;
        if(y<top+64 || y>bottom) return;
        float gap=10;
        float cw=(w-34-gap)/2f;
        float ch=(bottom-(top+68)-20)/3f;
        int col=x < w*.5f ? 0 : 1;
        int row=(int)((y-(top+64))/(ch+8));
        if(row<0 || row>2) return;
        int idx=row*2+col;
        double cost=upgradeCost(idx);
        if(cash>=cost) {
            cash-=cost;
            addLevel(idx);
            floats.add(new FloatingText(w*.5f,h*.26f,"SYSTEM UPGRADED",Color.rgb(78,220,126),1.1f));
            vibrate(24);
            saveNow();
        } else {
            floats.add(new FloatingText(w*.5f,h*.26f,"NOT ENOUGH CASH",Color.rgb(255,92,72),1.0f));
        }
    }

    private void handleBoostTap(float x,float y,int w,int h) {
        float top=h*.112f;
        if(y>top+80 && y<top+172) {
            if(gems>=10) { gems-=10; boostSeconds=Math.max(boostSeconds,300); vibrate(30); }
            else noGems(w,h);
        } else if(y>top+190 && y<top+282) {
            if(gems>=18) { gems-=18; overdriveSeconds=Math.max(overdriveSeconds,60); vibrate(45); }
            else noGems(w,h);
        } else if(y>top+300 && y<top+392) {
            if(crates>0) {
                crates--;
                double reward=passiveCashPerSecond()*(120+rng.nextInt(250));
                cash+=reward; totalCash+=reward;
                floats.add(new FloatingText(w*.5f,h*.32f,"CRATE  +"+fmt(reward),Color.rgb(198,93,255),1.4f));
                vibrate(36);
            }
        }
        saveNow();
    }

    private void noGems(int w,int h) {
        floats.add(new FloatingText(w*.5f,h*.30f,"NOT ENOUGH GEMS",Color.rgb(255,88,68),1.0f));
        vibrate(20);
    }

    private void tryPrestige() {
        if(bestDepth<10000) {
            floats.add(new FloatingText(getWidth()*.5f,getHeight()*.68f,"REACH 10 km FIRST",Color.rgb(255,91,70),1.2f));
            return;
        }
        prestige++;
        depth=0;
        cash=460;
        drillLevel=speedLevel=torqueLevel=coolingLevel=scannerLevel=batteryLevel=1;
        heat=12; energy=100; combo=1;
        floats.add(new FloatingText(getWidth()*.5f,getHeight()*.50f,"CORE REBUILT  +42% OUTPUT",Color.rgb(255,177,52),1.8f));
        vibrate(80);
        saveNow();
    }

    @Override public boolean performClick() {
        super.performClick();
        return true;
    }

    private void vibrate(long ms) {
        try {
            Vibrator v=(Vibrator)getContext().getSystemService(Context.VIBRATOR_SERVICE);
            if(v==null) return;
            if(Build.VERSION.SDK_INT>=26) v.vibrate(VibrationEffect.createOneShot(ms,VibrationEffect.DEFAULT_AMPLITUDE));
            else v.vibrate(ms);
        } catch(Exception ignored) {}
    }

    private String depthLabel() {
        return depth<1000 ? ((int)depth)+" m" : one.format(depth/1000.0)+" km";
    }

    private String fmt(double n) {
        if(n<1000) return two.format(n);
        String[] s={"K","M","B","T","aa","ab","ac","ad","ae"};
        int i=-1;
        while(n>=1000 && i<s.length-1){ n/=1000.0; i++; }
        return two.format(n)+(i>=0?s[i]:"");
    }

    private String layerName(double d) {
        if(d<250) return "SOIL";
        if(d<800) return "STONE";
        if(d<1800) return "IRON";
        if(d<3200) return "CRYSTAL";
        if(d<5200) return "MAGMA";
        if(d<8000) return "OBSIDIAN";
        return "CORE";
    }

    private int layerAccent(double d) {
        if(d<250) return Color.rgb(213,130,63);
        if(d<800) return Color.rgb(157,164,169);
        if(d<1800) return Color.rgb(196,117,72);
        if(d<3200) return Color.rgb(82,199,255);
        if(d<5200) return Color.rgb(255,91,34);
        if(d<8000) return Color.rgb(161,85,234);
        return Color.rgb(255,198,55);
    }

    private int layerColor(double d) {
        if(d<250) return Color.rgb(73,45,29);
        if(d<800) return Color.rgb(61,61,62);
        if(d<1800) return Color.rgb(76,55,45);
        if(d<3200) return Color.rgb(35,58,71);
        if(d<5200) return Color.rgb(76,31,24);
        if(d<8000) return Color.rgb(36,29,48);
        return Color.rgb(54,39,18);
    }

    private double layerValue(double d) {
        if(d<250) return 1.0;
        if(d<800) return 1.65;
        if(d<1800) return 2.6;
        if(d<3200) return 4.2;
        if(d<5200) return 7.1;
        if(d<8000) return 12.5;
        return 21.0;
    }

    private double layerHardness(double d) {
        if(d<250) return 0.0;
        if(d<800) return 0.4;
        if(d<1800) return 0.9;
        if(d<3200) return 1.5;
        if(d<5200) return 2.3;
        if(d<8000) return 3.2;
        return 4.4;
    }

    private int darken(int c,float f) {
        return Color.rgb((int)(Color.red(c)*(1-f)),(int)(Color.green(c)*(1-f)),(int)(Color.blue(c)*(1-f)));
    }

    private int lighten(int c,float f) {
        return Color.rgb(
                (int)(Color.red(c)+(255-Color.red(c))*f),
                (int)(Color.green(c)+(255-Color.green(c))*f),
                (int)(Color.blue(c)+(255-Color.blue(c))*f));
    }

    private static double clamp(double v,double lo,double hi){ return Math.max(lo,Math.min(hi,v)); }
    private static float clampf(float v,float lo,float hi){ return Math.max(lo,Math.min(hi,v)); }
    private static float lerp(float a,float b,float t){ return a+(b-a)*t; }
}
