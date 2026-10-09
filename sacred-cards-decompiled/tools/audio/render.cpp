// Small offline frontend to agbplay; game assets are read only from local ROM.
#include "MP2KContext.hpp"
#include "MP2KScanner.hpp"
#include "Rom.hpp"
#include <fstream>
#include <iostream>
#include <iterator>
#include <sndfile.h>
#include <cmath>

// Buffer-only ROM adapter avoids zip, GSF, UI and global settings dependencies.
Rom Rom::LoadFromBufferRef(std::span<uint8_t> data) {
    Rom rom; rom.romData = data; return rom;
}
bool Rom::IsGsf() const { return false; }

int main(int argc, char **argv) {
    try {
        if (argc < 2) throw std::runtime_error("Usage: render ROM [song_id output.wav [max_seconds]]");
        std::ifstream input(argv[1], std::ios::binary);
        if (!input) throw std::runtime_error("Cannot open ROM");
        std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(input)), {});
        auto rom = Rom::LoadFromBufferRef(bytes);
        auto found = MP2KScanner(rom).Scan(nullptr);
        if (found.size() != 1) throw std::runtime_error("Expected exactly one MP2K engine");
        const auto &f = found.at(0);
        std::cout << "table=" << std::hex << f.songTableInfo.pos << std::dec
                  << " count=" << f.songTableInfo.count << " vol=" << int(f.mp2kSoundMode.vol)
                  << " reverb=" << int(f.mp2kSoundMode.rev) << " freq=" << int(f.mp2kSoundMode.freq)
                  << " channels=" << int(f.mp2kSoundMode.maxChannels) << " dac=" << int(f.mp2kSoundMode.dacConfig) << '\n';
        for (size_t i=0;i<f.playerTableInfo.size();++i)
            std::cout << "player=" << i << " tracks=" << int(f.playerTableInfo[i].maxTracks)
                      << " priority=" << int(f.playerTableInfo[i].usePriority) << '\n';
        if (argc == 2) return 0;
        if (argc < 4) throw std::runtime_error("Missing output path");
        unsigned id = std::stoul(argv[2]);
        if (id >= f.songTableInfo.count) throw std::runtime_error("Song ID out of range");
        const size_t rate = 48000;
        const double maxSeconds = argc > 4 ? std::stod(argv[4]) : 600.0;
        MP2KContext ctx(rate, 2, rom, f.mp2kSoundMode, AgbplaySoundMode{}, f.songTableInfo, f.playerTableInfo);
        ctx.m4aSongNumStart(static_cast<uint16_t>(id));
        SF_INFO info{}; info.samplerate=rate; info.channels=2; info.format=SF_FORMAT_WAV|SF_FORMAT_FLOAT;
        SNDFILE *out = sf_open(argv[3], SFM_WRITE, &info);
        if (!out) throw std::runtime_error(sf_strerror(nullptr));
        size_t frames=0; double peak=0; bool ended=false;
        while (frames < static_cast<size_t>(maxSeconds*rate)) {
            ctx.m4aSoundMain();
            if (ctx.SongEnded()) { ended=true; break; }
            auto &buffer=ctx.masterAudioBuffer;
            for (const auto &s:buffer) {
                if (!std::isfinite(s.left) || !std::isfinite(s.right)) throw std::runtime_error("Nonfinite audio");
                peak=std::max(peak,std::max(std::abs(double(s.left)),std::abs(double(s.right))));
            }
            if (sf_writef_float(out,reinterpret_cast<float*>(buffer.data()),buffer.size()) != static_cast<sf_count_t>(buffer.size()))
                throw std::runtime_error("Audio write failed");
            frames+=buffer.size();
        }
        if (sf_close(out)) throw std::runtime_error("Audio close failed");
        std::cout << "render id=" << id << " frames=" << frames << " seconds=" << double(frames)/rate
                  << " peak=" << peak << " ended=" << ended << '\n';
        return ended ? 0 : 2;
    } catch (const std::exception &e) { std::cerr << e.what() << '\n'; return 1; }
}
