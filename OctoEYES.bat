@echo off
setlocal
set "SELF=%~f0"
title Oeil
mode con: cols=120 lines=40 >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:SELF);$i=$s.IndexOf('#PS'+'START');iex $s.Substring($i)"
if errorlevel 1 pause
exit /b
#PSSTART
$ErrorActionPreference = 'Stop'
try {
    Write-Host 'chargement de l oeil...'
    $src = @'
using System;
using System.IO;
using System.Text;
using System.Diagnostics;
using System.Threading;
using System.Runtime.InteropServices;

public static class OeilFX
{
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint mode);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint mode);

    //CORE-BEGIN
    const double PI = 3.14159265358979;
    const double CYCLE = 20.0;

    static double eo, ecx, ecy, erp, ez, erot, etw, etun, eglitch, ewash, efin;
    static double cR, cG, cB;
    static char cCh;
    static int oR, oG, oB;
    static char oC;

    static double Sat(double x) { return x < 0.0 ? 0.0 : (x > 1.0 ? 1.0 : x); }
    static double Smooth(double e0, double e1, double x)
    {
        double t = Sat((x - e0) / (e1 - e0));
        return t * t * (3.0 - 2.0 * t);
    }
    static double Lerp(double a, double b, double t) { return a + (b - a) * t; }

    static double Hash(int x, int y)
    {
        uint h = (uint)x * 374761393u + (uint)y * 668265263u;
        h = (h ^ (h >> 13)) * 1274126177u;
        h = h ^ (h >> 16);
        return (double)(h & 0xFFFFFFu) / 16777215.0;
    }
    static double Noise(double x, double y)
    {
        int xi = (int)Math.Floor(x), yi = (int)Math.Floor(y);
        double xf = x - xi, yf = y - yi;
        double u = xf * xf * (3.0 - 2.0 * xf), v = yf * yf * (3.0 - 2.0 * yf);
        double a = Hash(xi, yi), b = Hash(xi + 1, yi), c = Hash(xi, yi + 1), d = Hash(xi + 1, yi + 1);
        return Lerp(Lerp(a, b, u), Lerp(c, d, u), v);
    }
    static double Fbm(double x, double y)
    {
        double s = 0.0, amp = 0.5;
        for (int i = 0; i < 4; i++)
        {
            s += amp * Noise(x, y);
            x = x * 2.03 + 7.1; y = y * 2.03 + 3.7; amp *= 0.5;
        }
        return s / 0.9375;
    }
    static double EaseOut(double p)
    {
        p = Sat(p);
        return 1.0 - (1.0 - p) * (1.0 - p) * (1.0 - p);
    }
    static double Blink(double t, double t0, double dur)
    {
        double p = (t - t0) / dur;
        if (p <= 0.0 || p >= 1.0) return 0.0;
        if (p < 0.38) { double q = p / 0.38; return q * q * (3.0 - 2.0 * q); }
        double q2 = (p - 0.38) / 0.62;
        return 1.0 - q2 * q2 * (3.0 - 2.0 * q2);
    }
    static double Bump(double t, double c, double w)
    {
        double k = 1.0 - Math.Abs(t - c) / w;
        return k > 0.0 ? k : 0.0;
    }

    static void Tunnel(double px, double py, int gx, int gy, double tph, double tm)
    {
        double r = Math.Sqrt(px * px + py * py) + 0.00001;
        double ang = Math.Atan2(py, px);
        double d = -2.4 * Math.Log(r) + tph;
        double aa = ang / (2.0 * PI) * 16.0 + d * 0.05;
        double fr = d - Math.Floor(d);
        double fa = aa - Math.Floor(aa);
        double g1 = Math.Abs(fr - 0.5) * 2.0;
        double g2 = Math.Abs(fa - 0.5) * 2.0;
        double line = Math.Max(Smooth(0.80, 0.93, g1), 0.9 * Smooth(0.82, 0.94, g2));
        int ca = (int)Math.Floor(aa), cd = (int)Math.Floor(d);
        double hh = Hash(ca, cd);
        double hue = d * 0.045 + 0.50;
        double tr = 0.5 + 0.5 * Math.Cos(2.0 * PI * hue);
        double tg = 0.5 + 0.5 * Math.Cos(2.0 * PI * (hue + 0.10));
        double tb = 0.5 + 0.5 * Math.Cos(2.0 * PI * (hue + 0.25));
        double tm2 = Math.Max(tr, Math.Max(tg, tb)) + 0.001;
        tr /= tm2; tg /= tm2; tb /= tm2;
        double fade = Smooth(0.0, 0.25, r);
        bool lightTile = (((ca + cd) & 1) == 0);
        double tile = lightTile ? 0.26 : 0.07;
        if (hh > 0.90) tile = 0.70;
        double br = Math.Max(line * 1.20, tile);
        char ch = '\0';
        if (line < 0.3 && lightTile)
        {
            int fl = (int)(tm * 6.0);
            double hv = Hash(gx * 7 + fl, gy * 13 + fl * 3);
            if (hv < 0.22) { ch = (hv < 0.11) ? '0' : '1'; br = 0.80; }
        }
        br *= fade;
        double core = Math.Exp(-r * r * 22.0);
        if (core > 0.25) ch = '\0';
        cR = tr * br + 0.70 * core;
        cG = tg * br + 0.90 * core;
        cB = tb * br + 1.00 * core;
        cCh = ch;
    }

    static void Pixel(double su, double sv, int gx, int gy, double tm)
    {
        double cs = Math.Cos(erot), sn = Math.Sin(erot);
        double ru = su * cs - sv * sn, rv = su * sn + sv * cs;
        double u = ecx + (ru - ecx) / ez;
        double v = ecy + (rv - ecy) / ez;
        double dxp = u - ecx, dyp = v - ecy;
        double reye = Math.Sqrt(dxp * dxp + dyp * dyp);
        double a = 1.30;
        double tt = u / a;
        double ta = Math.Abs(tt);
        double h = 1.0 - tt * tt;
        if (h < 0.0) h = 0.0;
        double Lc = 0.10 * h;
        double yu = Lc - 0.72 * eo * Math.Pow(h, 0.85) - 0.05 * tt;
        double yl = Lc + 0.34 * eo * Math.Pow(h, 1.10) - 0.05 * tt;
        double du = v - yu, dl = yl - v;
        bool inside = (h > 0.0 && du > 0.0 && dl > 0.0);
        double fr, fg, fb;
        cCh = '\0';

        if (!inside)
        {
            double f0 = 0.46 - 0.10 * v;
            double nz = Noise(u * 14.0, v * 7.0) * 0.35 + Noise(u * 41.0 + 9.0, v * 20.0) * 0.25;
            double f = f0 * (0.80 + 0.5 * nz);
            double ox = (ta > 1.0) ? (ta - 1.0) * a : 0.0;
            double oy = 0.0;
            if (v < yu) oy = yu - v; else if (v > yl) oy = v - yl;
            double gd = Math.Sqrt(ox * ox + oy * oy);
            f *= 0.80 + 0.20 * Smooth(0.0, 0.40, gd);
            double yc = yu - 0.16 - 0.15 * eo * Math.Pow(h, 0.7);
            double dc = v - yc;
            if (ta < 1.12)
            {
                if (Math.Abs(dc) < 0.030) f *= 0.40;
                else if (dc > 0.0 && v < yu) f *= 1.20;
            }
            double yb2 = yl + 0.16;
            if (ta < 0.9 && Math.Abs(v - yb2) < 0.02) f *= 0.70;
            fr = 0.82 * f; fg = 0.57 * f; fb = 0.45 * f;

            double yb = -0.82 + 0.26 * tt * tt - 0.06 * tt;
            double bt = 0.10 * (1.25 - 0.55 * ta);
            if (ta < 1.2 && bt > 0.0)
            {
                double dbr = Math.Abs(v - yb);
                if (dbr < bt)
                {
                    double prob = Math.Sqrt(1.0 - dbr / bt) + 0.15;
                    if (Hash(gx + 5, gy) < prob)
                    {
                        double hv = 0.7 + 0.6 * Hash(gx * 3, gy);
                        fr = 0.36 * hv; fg = 0.24 * hv; fb = 0.17 * hv;
                        cCh = (tt < 0.0) ? '/' : '\\';
                        if (Hash(gx, gy + 9) < 0.22) cCh = '|';
                    }
                }
            }
            if (v < yu && h > 0.02 && ta < 0.97)
            {
                double ph = tt * 13.0;
                double idx = Math.Floor(ph);
                double fp = ph - idx;
                double len = 0.20 * Math.Pow(h, 0.5) * (0.45 + 0.55 * Hash((int)idx, 3)) * (0.25 + 0.75 * eo);
                if (yu - v < len && Math.Abs(fp - 0.5) < 0.22)
                {
                    fr = 0.70; fg = 0.50; fb = 0.42;
                    cCh = (tt < -0.25) ? '\\' : ((tt > 0.25) ? '/' : '|');
                }
            }
        }
        else
        {
            double sh = 1.0 - 0.50 * tt * tt;
            double ls = 0.40 + 0.60 * Smooth(0.0, 0.30, du);
            double lw = 0.78 + 0.22 * Smooth(0.0, 0.12, dl);
            double sc = sh * ls * lw;
            fr = 0.93 * sc; fg = 0.90 * sc; fb = 0.84 * sc;
            double vv = 1.0 - Math.Abs(2.0 * Noise(u * 8.0 + 5.0, v * 8.0 + 2.0) - 1.0);
            double vein = Math.Pow(vv, 10.0) * Smooth(0.25, 1.0, ta) * 0.8;
            fr = Lerp(fr, 0.78 * sc, vein); fg = Lerp(fg, 0.16 * sc, vein); fb = Lerp(fb, 0.16 * sc, vein);
            double cw = Smooth(-0.78, -0.97, tt) * 0.9;
            fr = Lerp(fr, 0.77, cw); fg = Lerp(fg, 0.40, cw); fb = Lerp(fb, 0.40, cw);

            const double RI = 0.52;
            if (reye < RI)
            {
                double rn = reye / RI, pn = erp / RI;
                double ang = Math.Atan2(dyp, dxp);
                double ca = Math.Cos(ang), sa = Math.Sin(ang);
                double fib1 = Fbm(ca * 5.0 + rn * 0.9, sa * 5.0 - rn * 0.9);
                double f2 = Noise(ca * 14.0 + 11.0, sa * 14.0 + 3.0 + rn * 0.4);
                double fib = 0.50 + 0.85 * fib1 + 0.35 * (f2 - 0.5);
                double s = Sat((rn - pn) / (1.0 - pn));
                double ir, ig, ib;
                if (s < 0.30) { double q = s / 0.30; ir = Lerp(1.00, 0.12, q); ig = Lerp(0.67, 0.85, q); ib = Lerp(0.16, 0.66, q); }
                else if (s < 0.72) { double q = (s - 0.30) / 0.42; ir = Lerp(0.12, 0.08, q); ig = Lerp(0.85, 0.43, q); ib = Lerp(0.66, 0.80, q); }
                else { double q = (s - 0.72) / 0.28; ir = Lerp(0.08, 0.02, q); ig = Lerp(0.43, 0.10, q); ib = Lerp(0.80, 0.25, q); }
                double ring = Math.Exp(-Math.Pow((s - 0.27) / 0.05, 2.0));
                double limb = Smooth(1.0, 0.86, rn);
                double lsi = 0.30 + 0.70 * Smooth(0.0, 0.26, du);
                double km = fib * (1.0 + 0.6 * ring) * (0.25 + 0.75 * limb) * lsi;
                ir *= km; ig *= km; ib *= km;
                double aaI = Smooth(RI, RI - 0.015, reye);
                fr = Lerp(fr, ir, aaI); fg = Lerp(fg, ig, aaI); fb = Lerp(fb, ib, aaI);
            }

            double pm = Smooth(erp, erp - 0.012, reye);
            if (pm > 0.0)
            {
                double den = erp * ez;
                if (den > 1.0) den = 1.0;
                double px = dxp * ez / den, py = dyp * ez / den;
                Tunnel(px, py, gx, gy, etun, tm);
                char tc = cCh;
                fr = Lerp(fr, cR * etw, pm); fg = Lerp(fg, cG * etw, pm); fb = Lerp(fb, cB * etw, pm);
                cCh = (pm > 0.5 && etw > 0.05) ? tc : '\0';
            }

            double hf = 1.0 - Smooth(1.4, 3.2, ez);
            if (hf > 0.0 && reye < RI * 1.02)
            {
                double h1x = 0.55 * ecx - 0.20, h1y = 0.55 * ecy - 0.21;
                double d1 = Math.Sqrt((u - h1x) * (u - h1x) + (v - h1y) * (v - h1y));
                double s1 = Smooth(0.085, 0.060, d1) * hf;
                double h2x = 0.55 * ecx + 0.16, h2y = 0.55 * ecy + 0.18;
                double d2 = Math.Sqrt((u - h2x) * (u - h2x) + (v - h2y) * (v - h2y));
                double s2 = Smooth(0.045, 0.030, d2) * 0.55 * hf;
                double hs = Math.Max(s1, s2);
                fr = Lerp(fr, 1.0, hs); fg = Lerp(fg, 1.0, hs); fb = Lerp(fb, 1.0, hs);
                if (hs > 0.4) cCh = '\0';
            }

            if (du < 0.04)
            {
                double k = Smooth(0.04, 0.012, du) * 0.9;
                fr *= 1.0 - k; fg *= 1.0 - k; fb *= 1.0 - k;
            }
            if (dl < 0.045)
            {
                double k2 = Smooth(0.045, 0.012, dl) * 0.8;
                fr = Lerp(fr, 0.86, k2); fg = Lerp(fg, 0.42, k2); fb = Lerp(fb, 0.44, k2);
            }
        }

        double slit = Math.Exp(-Math.Pow((v - Lc) / 0.05, 2.0)) * Math.Pow(h, 1.4) * Smooth(0.45, 0.0, eo);
        cR = fr + 0.12 * slit;
        cG = fg + 0.95 * slit;
        cB = fb + 0.85 * slit;
    }

    static void Setup(double t, int cyc)
    {
        double ob = (t < 0.9) ? 0.0 : EaseOut((t - 0.9) / 1.7);
        double bl = Math.Max(Math.Max(Blink(t, 4.0, 0.26), Blink(t, 5.6, 0.24)),
                             Math.Max(Blink(t, 5.95, 0.24), Blink(t, 7.4, 0.55)));
        eo = ob * (1.0 - bl);
        double lk = Smooth(5.9, 7.0, t);
        double gx = (0.75 * Math.Sin(t * 0.85 + 0.5) + 0.25 * Math.Sin(t * 2.1)) * (1.0 - lk);
        double gy = (0.55 * Math.Sin(t * 1.25 + 1.0)) * (1.0 - lk);
        ecx = gx * 0.36; ecy = gy * 0.12;
        erp = 0.185 + 0.012 * Math.Sin(t * 1.7) + 0.11 * (1.0 - Smooth(0.9, 3.5, t)) + 0.045 * Smooth(5.6, 7.3, t);
        double zp = Sat((t - 7.95) / 4.05);
        double ze = Math.Pow(zp, 1.6);
        ez = Math.Exp(Math.Log(12.0) * ze);
        erot = 0.6 * ze;
        etw = Smooth(1.2, 3.2, ez);
        double tp = (t > 7.95) ? (t - 7.95) : 0.0;
        etun = tp * (1.0 + 2.0 * ze);
        eglitch = Math.Max(Bump(t, 7.95, 0.45), Bump(t, 10.8, 0.5));
        ewash = Math.Max(Smooth(18.9, 19.85, t), (cyc > 0) ? (1.0 - Smooth(0.0, 0.9, t)) : 0.0);
        efin = (cyc == 0) ? Smooth(0.0, 0.9, t) : 1.0;
    }

    static char RampChar(int i)
    {
        switch (i)
        {
            case 0: return ' ';
            case 1: return '.';
            case 2: return ':';
            case 3: return '-';
            case 4: return '=';
            case 5: return '+';
            case 6: return '*';
            case 7: return '#';
            case 8: return '%';
            default: return '@';
        }
    }

    static void CellAt(int x, int y, int W, int H, double t, int fi, double bz)
    {
        double su = ((x + 0.5 - W * 0.5) / H) * bz;
        double sv = ((y + 0.5 - H * 0.5) * 2.0 / H) * bz;
        if (eglitch > 0.0)
        {
            if (Hash(y, fi) > 1.0 - 0.28 * eglitch)
                su += (Hash(y + 99, fi) - 0.5) * 0.9 * eglitch;
        }
        Pixel(su, sv, x, y, t);
        double r = cR, g = cG, b = cB;
        double vg = 1.0 - 0.55 * Smooth(0.55, 1.75, Math.Sqrt(su * su * 0.6 + sv * sv));
        double sc = vg * efin;
        if ((y & 1) == 1) sc *= 0.90;
        sc *= 0.92 + 0.16 * Hash(x * 3 + fi, y * 5 + fi * 7);
        r *= sc; g *= sc; b *= sc;
        r = Lerp(r, 1.0, ewash); g = Lerp(g, 1.0, ewash); b = Lerp(b, 1.0, ewash);
        double L = 0.299 * r + 0.587 * g + 0.114 * b;
        char ch;
        if (cCh != '\0' && ewash < 0.5) ch = cCh;
        else ch = RampChar((int)(Math.Pow(Sat(L * 1.15), 0.85) * 9.999));
        double mx = Math.Max(r, Math.Max(g, b));
        double k = (mx > 0.0005) ? Math.Min(1.0, 0.40 + 0.80 * mx) / mx : 0.0;
        oR = (int)(Sat(r * k) * 23.999) * 11;
        oG = (int)(Sat(g * k) * 23.999) * 11;
        oB = (int)(Sat(b * k) * 23.999) * 11;
        oC = ch;
    }
    //CORE-END

    static void EnableVT()
    {
        try
        {
            IntPtr h = GetStdHandle(-11);
            uint m;
            if (GetConsoleMode(h, out m)) SetConsoleMode(h, m | 5u);
        }
        catch (Exception) { }
    }

    static void Wr(Stream s, string str)
    {
        byte[] b = Encoding.ASCII.GetBytes(str);
        s.Write(b, 0, b.Length);
        s.Flush();
    }

    static bool KeyHit()
    {
        try { return Console.KeyAvailable; } catch (Exception) { return false; }
    }

    public static void Run()
    {
        const char ESC = (char)27;
        string L1 = "welcome";
        string L2 = "to OctoEYES.";
        string HINT = "[ n'importe quelle touche : quitter ]";
        EnableVT();
        try { Console.TreatControlCAsInput = true; } catch (Exception) { }
        Stream so = Console.OpenStandardOutput();
        StringBuilder sb = new StringBuilder(1 << 18);
        Wr(so, ESC + "[?1049h" + ESC + "[?25l" + ESC + "[48;2;0;0;0m" + ESC + "[2J");
        try
        {
            Stopwatch sw = Stopwatch.StartNew();
            int lastWW = -1, lastWH = -1, fi = 0;
            while (true)
            {
                if (KeyHit()) { Console.ReadKey(true); break; }
                double frameStart = sw.Elapsed.TotalMilliseconds;
                double t = sw.Elapsed.TotalSeconds;
                int cyc = (int)(t / CYCLE);
                double tt = t - cyc * CYCLE;
                int ww = Console.WindowWidth, wh = Console.WindowHeight;
                if (ww != lastWW || wh != lastWH)
                {
                    Wr(so, ESC + "[48;2;0;0;0m" + ESC + "[2J");
                    lastWW = ww; lastWH = wh;
                }
                int W = Math.Min(ww - 1, 130), H = Math.Min(wh - 1, 44);
                if (W < 30 || H < 10) { Thread.Sleep(100); continue; }
                int left = (ww - W) / 2, top = (wh - H) / 2;
                double aspect = (double)W / (2.0 * H);
                double bz = Math.Max(1.0, 1.45 / aspect);

                Setup(tt, cyc);

                int n1 = 0, n2 = 0;
                if (tt >= 13.2) n1 = (int)Math.Min((double)L1.Length, (tt - 13.2) / 0.09);
                if (tt >= 15.4) n2 = (int)Math.Min((double)L2.Length, (tt - 15.4) / 0.09);
                if (tt > 18.7) { n1 = 0; n2 = 0; }
                bool curOn = (((int)(tt * 2.5)) & 1) == 0;
                int tr1 = (int)(H * 0.64), tr2 = tr1 + 2;
                int ox1 = (W - L1.Length) / 2, ox2 = (W - L2.Length) / 2;
                int hx = (W - HINT.Length) / 2;
                bool showHint = (cyc == 0 && tt > 0.9 && tt < 4.5);

                sb.Length = 0;
                int last = -1;
                for (int y = 0; y < H; y++)
                {
                    sb.Append(ESC).Append('[').Append(top + y + 1).Append(';').Append(left + 1).Append('H');
                    for (int x = 0; x < W; x++)
                    {
                        CellAt(x, y, W, H, tt, fi, bz);
                        int cr = oR, cg = oG, cb = oB;
                        char ch = oC;
                        if (y == tr1 && n1 > 0 && x >= ox1 - 2 && x < ox1 + L1.Length + 2)
                        {
                            int k = x - ox1; ch = ' ';
                            if (k >= 0 && k < n1) ch = L1[k];
                            else if (k == n1 && n2 == 0 && curOn) ch = '_';
                            cr = 231; cg = 253; cb = 253;
                        }
                        else if (y == tr2 && n2 > 0 && x >= ox2 - 2 && x < ox2 + L2.Length + 2)
                        {
                            int k = x - ox2; ch = ' ';
                            if (k >= 0 && k < n2) ch = L2[k];
                            else if (k == n2 && curOn) ch = '_';
                            cr = 231; cg = 253; cb = 253;
                        }
                        else if (showHint && y == H - 1 && x >= hx && x < hx + HINT.Length)
                        {
                            ch = HINT[x - hx];
                            cr = 121; cg = 121; cb = 121;
                        }
                        int packed = (cr * 256 + cg) * 256 + cb;
                        if (packed != last)
                        {
                            sb.Append(ESC).Append("[38;2;").Append(cr).Append(';').Append(cg).Append(';').Append(cb).Append('m');
                            last = packed;
                        }
                        sb.Append(ch);
                    }
                }
                Wr(so, sb.ToString());
                fi++;
                double spent = sw.Elapsed.TotalMilliseconds - frameStart;
                if (spent < 33.0) Thread.Sleep((int)(33.0 - spent));
            }
        }
        finally
        {
            try { Console.TreatControlCAsInput = false; } catch (Exception) { }
            Wr(so, ESC + "[0m" + ESC + "[?25h" + ESC + "[?1049l");
        }
    }
}
'@
    Add-Type -TypeDefinition $src -Language CSharp
    [OeilFX]::Run()
} catch {
    Write-Host $_
    exit 1
}
