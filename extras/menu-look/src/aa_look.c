/*
 * aa-look - helper for the nbt-aa-tile "menu-look" extra (labels and images of the CarLife entry).
 *
 *   aa-look labels <brand> <src text.db> <dst text.db> [label]
 *       Writes a copy of the HMI text database where the CarLife entry's labels ("n. t. a. (ASIA)", "CarLife",
 *       "Baidu CarLife") read <label> (default "Android Auto"). Only the CarLife string IDs of <brand> are touched
 *       (bmw/bmwm/bmwi: 18 IDs, mini: 21 IDs), in every language, and only when their text is one of those.
 *       Refuses unless an untouched rebuild of <src> is byte-exact. The result is verified (every language
 *       decodes, changed languages read back exactly, unchanged ones are byte-identical) before it is written,
 *       and the written file is read back and compared.
 *       Exit: 0 written, 3 nothing to change, 1 usage, 2 file error, 4 format not understood, 5 verify failed.
 *   aa-look png <file>          prints "<width> <height> <colour type>" of a PNG (exit 4 if not a PNG)
 *   aa-look same <a> <b>        exit 0 if the two files are identical, 1 if not
 *   aa-look check <text.db>     parses and decodes every language, prints a summary (exit 4 if not understood)
 *
 * text.db format (big-endian u32 words), as documented by RRudkinp in NBT-AAD issue #55:
 *   0x00 magic 0xDECAFBAD, 0x20 + 4*i = offset of language table i (256 slots, 0 = none)
 *   table: handle, offset of the data block, alias (+ a terminator entry)
 *   data block: u32 flag (1 = compressed), u32 payload size, payload
 *   payload: u32 little-endian uncompressed size + UCL NRV2D (8-bit) stream
 *   text: UTF-16LE with BOM, lines "id<TAB>text\n"
 * The NRV2D decoder and encoder below are written for this program (standard UCL nrv2d bitstream).
 *
 * Builds for the head unit (QNX 6.5 ARM, see build.sh) and on a PC (cc -O2 aa_look.c) for testing.
 */
#ifdef QNX_TARGET
typedef unsigned int size_t;
int printf(const char*, ...); int fflush(void*); void* malloc(size_t); void* realloc(void*, size_t); void free(void*);
void* memcpy(void*, const void*, size_t); void* memset(void*, int, size_t); int memcmp(const void*, const void*, size_t);
int strcmp(const char*, const char*); size_t strlen(const char*); void exit(int);
int open(const char*, int, ...); int read(int, void*, size_t); int write(int, const void*, size_t); int close(int);
#define O_RDONLY 0
#define O_WRONLY 1
#define O_CREAT 0x100
#define O_TRUNC 0x200
#else
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#endif

#define VERSION "1"
typedef unsigned char u8; typedef unsigned short u16; typedef unsigned int u32;

/* ---------- files ---------- */
static u8* readFile(const char* path, u32* len) {
    int fd = open(path, O_RDONLY); u8* b = 0; u32 cap = 0, n = 0; int r;
    if (fd < 0) return 0;
    for (;;) {
        if (n + 65536 > cap) { u8* nb; cap = cap ? cap * 2 : (1u << 20); nb = (u8*)realloc(b, cap); if (!nb) { free(b); close(fd); return 0; } b = nb; }
        r = read(fd, b + n, 65536);
        if (r < 0) { free(b); close(fd); return 0; }
        if (r == 0) break;
        n += (u32)r;
    }
    close(fd);
    *len = n;
    return b;
}

static int writeFile(const char* path, const u8* b, u32 n) {
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644); u32 done = 0;
    if (fd < 0) return -1;
    while (done < n) {
        u32 chunk = n - done > 65536 ? 65536 : n - done;
        int w = write(fd, b + done, chunk);
        if (w <= 0) { close(fd); return -1; }
        done += (u32)w;
    }
    return close(fd) == 0 ? 0 : -1;
}

static u32 be32(const u8* p) { return ((u32)p[0] << 24) | ((u32)p[1] << 16) | ((u32)p[2] << 8) | p[3]; }
static void putBe32(u8* p, u32 v) { p[0] = v >> 24; p[1] = v >> 16; p[2] = v >> 8; p[3] = v; }
static u32 le32(const u8* p) { return p[0] | (p[1] << 8) | (p[2] << 16) | ((u32)p[3] << 24); }

/* ---------- NRV2D (8-bit) decoder ---------- */
/* src = stream after the u32 LE size. Returns 0 and fills out (exactly n bytes) or -1. */
static int nrv2dDecode(const u8* src, u32 slen, u8* out, u32 n) {
    u32 ip = 0, op = 0, bb = 0, last = 1;
#define GETBIT(b) do { if ((bb & 0x7f) == 0) { if (ip >= slen) return -1; bb = ((u32)src[ip++] << 1) | 1; } else bb <<= 1; \
                       (b) = (bb >> 8) & 1; bb &= 0x1ff; } while (0)
    /* bb holds the current byte shifted: bit 8 is the next bit to read. Equivalent to UCL getbit_8. */
    bb = 0;
    for (;;) {
        u32 b, moff, mlen;
        for (;;) {
            GETBIT(b);
            if (!b) break;
            if (ip >= slen || op >= n) return -1;
            out[op++] = src[ip++];
        }
        moff = 1;
        for (;;) {
            GETBIT(b); moff = moff * 2 + b;
            GETBIT(b); if (b) break;
            GETBIT(b); moff = (moff - 1) * 2 + b;
            if (moff > 0x1000003) return -1;
        }
        if (moff == 2) { moff = last; GETBIT(mlen); }
        else {
            if (ip >= slen) return -1;
            moff = (moff - 3) * 256 + src[ip++];
            if (moff == 0xffffffffu) break;
            mlen = (moff ^ 0xffffffffu) & 1;
            moff >>= 1; moff += 1; last = moff;
        }
        GETBIT(b); mlen = mlen * 2 + b;
        if (mlen == 0) {
            mlen = 1;
            for (;;) { GETBIT(b); mlen = mlen * 2 + b; GETBIT(b); if (b) break; if (mlen > n) return -1; }
            mlen += 2;
        }
        if (moff > 0x500) mlen += 1;
        if (moff > op || op + mlen + 1 > n) return -1;
        { u32 k; for (k = 0; k <= mlen; ++k) { out[op] = out[op - moff]; ++op; } }
    }
#undef GETBIT
    return op == n ? 0 : -1;
}

/* ---------- NRV2D (8-bit) encoder ---------- */
typedef struct { u8* b; u32 n, cap; u32 bitpos; u32 nbits; } BW;
static int bwGrow(BW* w, u32 more) {
    if (w->n + more > w->cap) { u32 c = w->cap * 2 + more + 4096; u8* nb = (u8*)realloc(w->b, c); if (!nb) return -1; w->b = nb; w->cap = c; }
    return 0;
}
static int bwBit(BW* w, u32 bit) {
    if ((w->nbits & 7) == 0) { if (bwGrow(w, 1)) return -1; w->bitpos = w->n; w->b[w->n++] = 0; }
    if (bit) w->b[w->bitpos] |= (u8)(0x80 >> (w->nbits & 7));
    w->nbits++;
    return 0;
}
static int bwByte(BW* w, u8 v) { if (bwGrow(w, 1)) return -1; w->b[w->n++] = v; return 0; }

/* M >= 2, as read by: m=1; loop { m=2m+a; if (stop) break; m=(m-1)*2+c } */
static int encM(BW* w, u32 M) {
    u32 a[40], c[40]; int k = 0, i;
    for (;;) {
        u32 prev = M >> 1;
        a[k] = M & 1;
        if (prev == 1) { k++; break; }
        c[k] = prev & 1;
        M = (prev >> 1) + 1;
        k++;
        if (k >= 40) return -1;
    }
    /* iterations were collected last-first */
    for (i = k - 1; i >= 0; --i) {
        if (bwBit(w, a[i])) return -1;
        if (i == 0) { if (bwBit(w, 1)) return -1; }
        else { if (bwBit(w, 0)) return -1; if (bwBit(w, c[i - 1])) return -1; }
    }
    return 0;
}

#define HBITS 16
#define MAXCHAIN 48
#define WINDOW 0x100000u
#define MAXLEN 0x8000u

static u32 hash3(const u8* p) { return ((p[0] << 8) ^ (p[1] << 4) ^ p[2] ^ (p[2] << 10)) & ((1u << HBITS) - 1); }

/* returns the payload (u32 LE size + stream) in *out / *olen */
static int nrv2dEncode(const u8* d, u32 n, u8** out, u32* olen) {
    BW w; int* head; int* prev; u32 i = 0, last = 1, k;
    head = (int*)malloc(sizeof(int) << HBITS);
    prev = (int*)malloc(sizeof(int) * (n + 1));
    if (!head || !prev) { free(head); free(prev); return -1; }
    for (k = 0; k < (1u << HBITS); ++k) head[k] = -1;
    w.cap = n / 2 + 4096; w.b = (u8*)malloc(w.cap); w.n = 0; w.nbits = 0; w.bitpos = 0;
    if (!w.b) { free(head); free(prev); return -1; }
    w.b[0] = n; w.b[1] = n >> 8; w.b[2] = n >> 16; w.b[3] = n >> 24; w.n = 4;
#define INSERT(p) do { if ((p) + 2 < n) { u32 h_ = hash3(d + (p)); prev[p] = head[h_]; head[h_] = (int)(p); } } while (0)
    while (i < n) {
        u32 bestLen = 0, bestOff = 0, lim = n - i > MAXLEN ? MAXLEN : n - i;
        int bestEff = 0;
        if (i + 2 < n) {
            int cand = head[hash3(d + i)], chain = 0;
            while (cand >= 0 && chain < MAXCHAIN && i - (u32)cand <= WINDOW) {
                u32 o = i - (u32)cand, ln = 0; int eff;
                while (ln < lim && d[cand + ln] == d[i + ln]) ln++;
                eff = (int)ln - (o > 0x500 ? 1 : 0);
                if (ln >= 3 && eff > bestEff) { bestEff = eff; bestLen = ln; bestOff = o; }
                cand = prev[cand]; chain++;
            }
        }
        /* the last offset is cheap to reuse: take it when it is at least as good */
        if (last <= i) {
            u32 ln = 0; int eff;
            while (ln < lim && d[i - last + ln] == d[i + ln]) ln++;
            eff = (int)ln - (last > 0x500 ? 1 : 0);
            if (eff >= 2 && eff >= bestEff) { bestEff = eff; bestLen = ln; bestOff = last; }
        }
        if (bestLen && (bestEff >= 3 || (bestEff == 2 && bestOff == last))) {
            u32 o = bestOff, far = o > 0x500 ? 1 : 0;
            u32 mlen = bestLen - 1 - far;               /* the decoder copies mlen + 1 (+far) bytes */
            u32 L0, bitv, longv = 0;
            if (mlen == 1) { L0 = 0; bitv = 1; }
            else if (mlen == 2) { L0 = 1; bitv = 0; }
            else if (mlen == 3) { L0 = 1; bitv = 1; }
            else { L0 = 0; bitv = 0; longv = mlen - 2; }
            if (bwBit(&w, 0)) goto fail;
            if (o == last) {
                if (bwBit(&w, 0) || bwBit(&w, 1) || bwBit(&w, L0)) goto fail;  /* M == 2 */
            } else {
                u32 x = (o - 1) * 2 + (1 - L0);
                if (encM(&w, (x >> 8) + 3) || bwByte(&w, (u8)(x & 0xff))) goto fail;
                last = o;
            }
            if (bwBit(&w, bitv)) goto fail;
            if (longv) {
                int top = 31, j;
                while (!((longv >> top) & 1)) top--;
                for (j = top - 1; j >= 0; --j) {
                    if (bwBit(&w, (longv >> j) & 1)) goto fail;
                    if (bwBit(&w, j == 0 ? 1 : 0)) goto fail;
                }
            }
            for (k = 0; k < bestLen; ++k) INSERT(i + k);
            i += bestLen;
        } else {
            if (bwBit(&w, 1) || bwByte(&w, d[i])) goto fail;
            INSERT(i);
            i++;
        }
    }
#undef INSERT
    if (bwBit(&w, 0) || encM(&w, 0x1000002) || bwByte(&w, 0xff)) goto fail;
    free(head); free(prev);
    *out = w.b; *olen = w.n;
    return 0;
fail:
    free(head); free(prev); free(w.b);
    return -1;
}

/* ---------- text.db ---------- */
typedef struct { int idx; u32 table, off, flag, csz; } Lang;

static int parseDb(const u8* d, u32 n, Lang* L, int* nl) {
    int i, k = 0;
    if (n < 0x420 || be32(d) != 0xDECAFBADu) return -1;
    for (i = 0; i < 256; ++i) {
        u32 t = be32(d + 0x20 + 4 * i);
        if (!t) continue;
        if (t + 12 > n) return -1;
        L[k].idx = i; L[k].table = t; L[k].off = be32(d + t + 4);
        if (L[k].off + 8 > n) return -1;
        L[k].flag = be32(d + L[k].off); L[k].csz = be32(d + L[k].off + 4);
        if (L[k].off + 8 + L[k].csz > n) return -1;
        k++;
    }
    *nl = k;
    return k ? 0 : -1;
}

/* decoded text of one language (malloc'd) */
static u8* langText(const u8* d, const Lang* L, u32* tlen) {
    const u8* p = d + L->off + 8; u8* out; u32 n;
    if (L->flag != 1) {
        out = (u8*)malloc(L->csz ? L->csz : 1); if (!out) return 0;
        memcpy(out, p, L->csz); *tlen = L->csz; return out;
    }
    if (L->csz < 4) return 0;
    n = le32(p);
    if (n > 64u << 20) return 0;
    out = (u8*)malloc(n ? n : 1); if (!out) return 0;
    if (nrv2dDecode(p + 4, L->csz - 4, out, n)) { free(out); return 0; }
    *tlen = n;
    return out;
}

static void sortByOff(Lang* o, int nl) {
    int i, j;
    for (i = 1; i < nl; ++i) { Lang t = o[i]; j = i - 1; while (j >= 0 && o[j].off > t.off) { o[j + 1] = o[j]; j--; } o[j + 1] = t; }
}

/* newText[idx] = payload (u32 LE size + stream) or 0 to keep the original block */
static u8* buildDb(const u8* d, u32 n, u8** newPay, u32* newLen, u32* olen) {
    static Lang L[256], o[256]; int nl, i; u32 first, pos, total; u8* out;
    if (parseDb(d, n, L, &nl)) return 0;
    memcpy(o, L, sizeof(Lang) * nl);
    sortByOff(o, nl);
    first = o[0].off;
    total = first;
    for (i = 0; i < nl; ++i) total += newPay[o[i].idx] ? 8 + newLen[o[i].idx] : 8 + o[i].csz;
    out = (u8*)malloc(total); if (!out) return 0;
    memcpy(out, d, first);
    pos = first;
    for (i = 0; i < nl; ++i) {
        putBe32(out + o[i].table + 4, pos);
        if (newPay[o[i].idx]) {
            putBe32(out + pos, 1); putBe32(out + pos + 4, newLen[o[i].idx]);
            memcpy(out + pos + 8, newPay[o[i].idx], newLen[o[i].idx]);
            pos += 8 + newLen[o[i].idx];
        } else {
            memcpy(out + pos, d + o[i].off, 8 + o[i].csz);
            pos += 8 + o[i].csz;
        }
    }
    *olen = pos;
    return out;
}

/* CarLife string IDs (RRudkinp's list for BMW; the MINI database has 3 more) */
static const char* kIdsBmw[] = { "94480", "94488", "94608", "94616", "94648", "94664", "94672", "94673", "94696", "94697",
                                 "94699", "94704", "94705", "94707", "94712", "94713", "94714", "94715", 0 };
static const char* kIdsMiniExtra[] = { "95944", "96432", "96433", 0 };

/* old labels, UTF-16 code units */
static const u16 kOld1[] = { 'n','.',' ','t','.',' ','a','.',' ','(','A','S','I','A',')', 0 };
static const u16 kOld2[] = { 'C','a','r','L','i','f','e', 0 };
static const u16 kOld3[] = { 'B','a','i','d','u',' ','C','a','r','L','i','f','e', 0 };
static const u16 kOld4[] = { 0x767E, 0x5EA6, ' ', 'C','a','r','L','i','f','e', 0 };
static const u16 kOld5[] = { 0x767E, 0x5EA6, 'C','a','r','L','i','f','e', 0 };
static const u16* kOld[] = { kOld1, kOld2, kOld3, kOld4, kOld5, 0 };
/* the same labels in capitals (some languages show them that way): replaced by the label in capitals */
static const u16 kUp1[] = { 'N','.',' ','T','.',' ','A','.',' ','(','A','S','I','A',')', 0 };
static const u16 kUp2[] = { 'C','A','R','L','I','F','E', 0 };
static const u16 kUp3[] = { 'B','A','I','D','U',' ','C','A','R','L','I','F','E', 0 };
static const u16* kOldUp[] = { kUp1, kUp2, kUp3, 0 };

static int isMini;
static int idIn(const u16* k, u32 kl, const char** list) {
    int i; u32 j;
    for (i = 0; list[i]; ++i) {
        if (strlen(list[i]) != kl) continue;
        for (j = 0; j < kl && k[j] == (u16)(u8)list[i][j]; ++j) {}
        if (j == kl) return 1;
    }
    return 0;
}
static int idListed(const u16* k, u32 kl) { return idIn(k, kl, kIdsBmw) || (isMini && idIn(k, kl, kIdsMiniExtra)); }
static u16 upper(u16 c) { return c >= 'a' && c <= 'z' ? (u16)(c - 32) : c; }
static int valIs(const u16* v, u32 vl, const u16* s) { u32 j = 0; while (j < vl && s[j] && v[j] == s[j]) j++; return j == vl && !s[j]; }

/* Patches one language (UTF-16LE bytes, BOM first). Returns the new text (malloc'd, *outLen bytes) when at least
 * one line changed, else 0. Counts: changed lines, listed lines already reading the label, listed lines with
 * any other text (left alone). */
static u8* patchText(const u8* t, u32 tlen, const u16* label, u32 llen, int* changed, int* already, int* other, u32* outLen) {
    u32 nu = tlen / 2, i = 0, outN = 0, cap; u16* in; u16* out; int ch = 0;
    in = (u16*)malloc(tlen + 2);
    if (!in) return 0;
    memcpy(in, t, tlen);
    cap = nu + 16;
    out = (u16*)malloc(cap * 2);
    if (!out) { free(in); return 0; }
    while (i < nu) {
        u32 s = i, e, tab, ve, need; int listed, m = 0, q;
        while (i < nu && in[i] != '\n') i++;
        e = i;                                            /* line = [s, e); '\n' at e unless at the end */
        for (tab = s; tab < e && in[tab] != '\t'; ++tab) {}
        ve = e; if (ve > tab + 1 && in[ve - 1] == '\r') ve--;
        listed = tab < e && tab > s && idListed(in + s, tab - s);
        if (listed) {
            const u16* v = in + tab + 1; u32 vl = ve - tab - 1;
            for (q = 0; kOld[q]; ++q) if (valIs(v, vl, kOld[q])) { m = 1; break; }
            if (!m) for (q = 0; kOldUp[q]; ++q) if (valIs(v, vl, kOldUp[q])) { m = 2; break; }
            if (!m) {
                u32 j; int same = vl == llen, sameUp = vl == llen;
                for (j = 0; same && j < vl; ++j) if (v[j] != label[j]) same = 0;
                for (j = 0; sameUp && j < vl; ++j) if (v[j] != upper(label[j])) sameUp = 0;
                if (same || sameUp) (*already)++; else (*other)++;
            }
        }
        need = outN + (e - s) + llen + 2;
        if (need > cap) { u16* nb; cap = need + cap / 2; nb = (u16*)realloc(out, cap * 2); if (!nb) { free(in); free(out); return 0; } out = nb; }
        if (m) {
            memcpy(out + outN, in + s, (tab + 1 - s) * 2); outN += tab + 1 - s;
            { u32 j; for (j = 0; j < llen; ++j) out[outN++] = m == 2 ? upper(label[j]) : label[j]; }
            if (ve < e) out[outN++] = '\r';
            ch++;
        } else {
            memcpy(out + outN, in + s, (e - s) * 2); outN += e - s;
        }
        if (i < nu) { out[outN++] = '\n'; i++; }
    }
    if (tlen & 1) { free(in); free(out); return 0; }
    free(in);
    *changed = ch;
    if (!ch) { free(out); return 0; }
    *outLen = outN * 2;
    return (u8*)out;
}

static int cmdLabels(const char* brand, const char* src, const char* dst, const char* labelArg) {
    u8 *d, *outDb, *back; u32 n, on, bn; static Lang L[256], L2[256]; int nl, nl2, i, total = 0, langs = 0, already = 0, other = 0;
    static u8* newPay[256]; static u32 newLen[256]; static u8* newTxt[256]; static u32 newTxtLen[256];
    u16 label[64]; u32 llen = 0;
    const char* lab = labelArg ? labelArg : "Android Auto";
    if (!strcmp(brand, "mini")) isMini = 1;
    else if (!strcmp(brand, "bmw") || !strcmp(brand, "bmwm") || !strcmp(brand, "bmwi")) isMini = 0;
    else { printf("ERROR: brand must be bmw, bmwm, bmwi or mini\n"); return 1; }
    while (lab[llen]) {
        if (llen >= 40 || (u8)lab[llen] < 0x20 || (u8)lab[llen] > 0x7e) { printf("ERROR: the label must be 1-40 plain ASCII characters\n"); return 1; }
        label[llen] = (u8)lab[llen]; llen++;
    }
    if (!llen) { printf("ERROR: empty label\n"); return 1; }
    d = readFile(src, &n);
    if (!d) { printf("ERROR: cannot read %s\n", src); return 2; }
    if (parseDb(d, n, L, &nl)) { printf("ERROR: %s is not a text.db this program understands. Nothing written.\n", src); return 4; }
    memset(newPay, 0, sizeof(newPay)); memset(newLen, 0, sizeof(newLen));
    memset(newTxt, 0, sizeof(newTxt)); memset(newTxtLen, 0, sizeof(newTxtLen));
    outDb = buildDb(d, n, newPay, newLen, &on);
    if (!outDb || on != n || memcmp(outDb, d, n)) { printf("ERROR: an untouched rebuild is not byte-exact: this text.db is not understood. Nothing written.\n"); return 4; }
    free(outDb);
    printf("aa-look %s: %s, %u bytes, %d languages, brand %s, label \"%s\"\n", VERSION, src, n, nl, brand, lab);
    fflush(0);
    for (i = 0; i < nl; ++i) {
        u32 tl, ntl = 0; int ch = 0; u8* t = langText(d, &L[i], &tl); u8* nt;
        if (!t) { printf("ERROR: language %d does not decode. Nothing written.\n", L[i].idx); return 4; }
        if (tl < 2 || (tl & 1) || t[0] != 0xFF || t[1] != 0xFE) { printf("ERROR: language %d is not UTF-16LE text. Nothing written.\n", L[i].idx); return 4; }
        nt = patchText(t, tl, label, llen, &ch, &already, &other, &ntl);
        free(t);
        if (!ch) continue;
        if (!nt) { printf("ERROR: out of memory\n"); return 2; }
        if (nrv2dEncode(nt, ntl, &newPay[L[i].idx], &newLen[L[i].idx])) { printf("ERROR: out of memory\n"); return 2; }
        newTxt[L[i].idx] = nt; newTxtLen[L[i].idx] = ntl;
        total += ch; langs++;
        printf("language %3d: %d lines changed\n", L[i].idx, ch);
        fflush(0);
    }
    if (already || other) printf("CarLife IDs left alone: %d already read the label, %d have another text\n", already, other);
    if (!total) { printf("NOTHING TO CHANGE (already done, or this database has other IDs). Nothing written.\n"); return 3; }
    outDb = buildDb(d, n, newPay, newLen, &on);
    if (!outDb) { printf("ERROR: out of memory\n"); return 2; }
    /* verify the result in memory before writing anything */
    if (parseDb(outDb, on, L2, &nl2) || nl2 != nl) { printf("VERIFY FAILED: the new file does not parse. Nothing written.\n"); return 5; }
    for (i = 0; i < nl2; ++i) {
        int k, idx = L2[i].idx; u32 tl;
        for (k = 0; k < nl && L[k].idx != idx; ++k) {}
        if (k == nl) { printf("VERIFY FAILED: language %d missing. Nothing written.\n", idx); return 5; }
        if (newTxt[idx]) {
            u8* t = langText(outDb, &L2[i], &tl);
            if (!t || tl != newTxtLen[idx] || memcmp(t, newTxt[idx], tl)) { printf("VERIFY FAILED: language %d does not read back. Nothing written.\n", idx); return 5; }
            free(t);
        } else if (L2[i].csz != L[k].csz || memcmp(outDb + L2[i].off, d + L[k].off, 8 + L[k].csz)) {
            printf("VERIFY FAILED: language %d changed by mistake. Nothing written.\n", idx); return 5;
        }
    }
    if (writeFile(dst, outDb, on)) { printf("ERROR: cannot write %s\n", dst); return 2; }
    back = readFile(dst, &bn);
    if (!back || bn != on || memcmp(back, outDb, on)) { printf("VERIFY FAILED: %s does not read back as written\n", dst); return 5; }
    printf("OK: %d lines in %d languages -> %s (%u bytes)\n", total, langs, dst, on);
    return 0;
}

static int cmdCheck(const char* f) {
    u8* d; u32 n, on, sum = 0; static Lang L[256]; int nl, i; static u8* npay[256]; static u32 nlen[256]; u8* r;
    d = readFile(f, &n);
    if (!d) { printf("ERROR: cannot read %s\n", f); return 2; }
    if (parseDb(d, n, L, &nl)) { printf("NOT UNDERSTOOD: %s\n", f); return 4; }
    memset(npay, 0, sizeof(npay)); memset(nlen, 0, sizeof(nlen));
    r = buildDb(d, n, npay, nlen, &on);
    if (!r || on != n || memcmp(r, d, n)) { printf("NOT UNDERSTOOD: untouched rebuild differs\n"); return 4; }
    for (i = 0; i < nl; ++i) { u32 tl; u8* t = langText(d, &L[i], &tl); if (!t) { printf("NOT UNDERSTOOD: language %d does not decode\n", L[i].idx); return 4; } sum += tl; free(t); }
    printf("OK: %u bytes, %d languages, %u bytes of text\n", n, nl, sum);
    return 0;
}

static int cmdPng(const char* f) {
    u8* b; u32 n;
    b = readFile(f, &n);
    if (!b) { printf("ERROR: cannot read %s\n", f); return 2; }
    if (n < 26 || memcmp(b, "\x89PNG\r\n\x1a\n", 8) || memcmp(b + 12, "IHDR", 4)) { printf("NOTPNG\n"); free(b); return 4; }
    printf("%u %u %u\n", be32(b + 16), be32(b + 20), b[25]);
    free(b);
    return 0;
}

static int cmdSame(const char* a, const char* b) {
    u8 *x, *y; u32 nx, ny; int r;
    x = readFile(a, &nx); y = readFile(b, &ny);
    if (!x || !y) { printf("ERROR: cannot read %s\n", !x ? a : b); return 2; }
    r = nx == ny && !memcmp(x, y, nx) ? 0 : 1;
    free(x); free(y);
    return r;
}

int main(int argc, char** argv) {
    if (argc == 4 && !strcmp(argv[1], "same")) return cmdSame(argv[2], argv[3]);
    if (argc == 3 && !strcmp(argv[1], "png")) return cmdPng(argv[2]);
    if (argc == 3 && !strcmp(argv[1], "check")) return cmdCheck(argv[2]);
    if ((argc == 5 || argc == 6) && !strcmp(argv[1], "labels")) return cmdLabels(argv[2], argv[3], argv[4], argc == 6 ? argv[5] : 0);
    printf("aa-look %s\nusage: aa-look labels <bmw|bmwm|bmwi|mini> <src text.db> <dst text.db> [label]\n"
           "       aa-look png <file>\n       aa-look same <a> <b>\n       aa-look check <text.db>\n", VERSION);
    return 1;
}
