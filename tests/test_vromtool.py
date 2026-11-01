"""Regression tests for ADPCM-A page placement."""

import io
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import vromtool

PAGE = 1024 * 1024


def sample(kind, name, size, value=0x55):
    result = kind(name)
    result.data = bytes([value]) * size
    return result


class AdpcmAPagePlacementTests(unittest.TestCase):
    def test_adpcm_a_crossing_page_moves_to_next_page(self):
        samples = [sample(vromtool.adpcm_a, "first", 0xfe300),
                   sample(vromtool.adpcm_a, "earthquake", 0x2300),
                   sample(vromtool.adpcm_a, "next", 0x100)]
        vromtool.allocate_samples(samples, 2 * PAGE, "sampleX.rom")
        self.assertEqual([s.start for s in samples], [0, PAGE, PAGE + 0x2300])
        output = io.StringIO()
        vromtool.generate_asm_defines(samples, output)
        self.assertIn("[100000..1022ff] ADPCM-A", output.getvalue())

    def test_exact_page_end_does_not_add_padding(self):
        samples = [sample(vromtool.adpcm_a, "first", PAGE - 0x100),
                   sample(vromtool.adpcm_a, "end", 0x100),
                   sample(vromtool.adpcm_a, "next", 0x100)]
        vromtool.allocate_samples(samples, 2 * PAGE, "sampleX.rom")
        self.assertEqual([s.start for s in samples], [0, PAGE - 0x100, PAGE])

    def test_alignment_at_rom_end_allocates_next_rom(self):
        samples = [sample(vromtool.adpcm_a, "first", PAGE),
                   sample(vromtool.adpcm_a, "second", PAGE - 0x100),
                   sample(vromtool.adpcm_a, "next", 0x200)]
        vromtool.allocate_samples(samples, 2 * PAGE, "sampleX.rom")
        self.assertEqual(samples[2].out, "sample2.rom")
        self.assertEqual(samples[2].vrom_start, 0)
        self.assertEqual(samples[2].start, 2 * PAGE)

    def test_adpcm_a_larger_than_page_is_rejected(self):
        with self.assertRaises(SystemExit):
            vromtool.allocate_samples([sample(vromtool.adpcm_a, "large", PAGE + 0x100)],
                                      2 * PAGE, "sampleX.rom")

    def test_sample_larger_than_rom_is_rejected(self):
        with self.assertRaises(SystemExit):
            vromtool.allocate_samples([sample(vromtool.adpcm_a, "large", PAGE)],
                                      PAGE // 2, "sampleX.rom")

    def test_generated_rom_contains_padding_and_samples_at_reported_offsets(self):
        samples = [sample(vromtool.adpcm_a, "first", PAGE - 0x100),
                   sample(vromtool.adpcm_a, "second", 0x200, 0xaa)]
        with tempfile.TemporaryDirectory() as directory:
            pattern = str(Path(directory) / "sampleX.rom")
            vromtool.allocate_samples(samples, 2 * PAGE, pattern)
            vromtool.generate_vroms(samples, 2 * PAGE, pattern, 1)
            data = Path(samples[0].out).read_bytes()
        self.assertEqual(len(data), 2 * PAGE)
        self.assertEqual(data[:PAGE - 0x100], samples[0].data)
        self.assertEqual(data[PAGE - 0x100:PAGE], bytes(0x100))
        self.assertEqual(data[PAGE:PAGE + 0x200], samples[1].data)


if __name__ == "__main__":
    unittest.main()
