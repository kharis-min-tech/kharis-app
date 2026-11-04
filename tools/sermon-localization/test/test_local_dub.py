import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("local_dub", Path(__file__).parents[1] / "local-dub.py")
dub = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dub)


class TimelineTests(unittest.TestCase):
    def test_subtitles_keep_source_timing_and_escape_text(self):
        text = dub.subtitles([{"start": 61.25, "end": 64.5, "translation": "La foi & <la grâce>"}])
        self.assertIn("00:01:01.250 --> 00:01:04.500", text)
        self.assertIn("La foi &amp; &lt;la grâce&gt;", text)

    def test_timing_rounds_across_minute_boundary(self):
        self.assertEqual(dub.timestamp(59.9998), "00:01:00.000")

    def test_segments_cannot_overlap_or_outlast_recording(self):
        valid = [{"start": 0, "end": 2, "translation": "Bonjour"}]
        dub.validate_segments(valid, 3)
        for segments in [[], [{"start": -1, "end": 2, "translation": "x"}],
                         [{"start": 0, "end": 4, "translation": "x"}],
                         valid + [{"start": 1, "end": 3, "translation": "x"}],
                         [{"start": 0, "end": 1, "translation": ""}]]:
            with self.assertRaises(ValueError):
                dub.validate_segments(segments, 3)


if __name__ == "__main__":
    unittest.main()
