<?php

/*
	Ionity Bench
	URLs: https://www.ionity.today | https://github.com/Ionity-Global/ionity-bench
	Copyright (C) 2018 - 2026, Antwerp Designs | Ionity (Pty) Ltd - AEDI
	ionity.php: Ionity Bench overview command - banner, bundled suites and test profiles.
	Built on the Phoronix Test Suite (Copyright (C) 2008 - 2026, Phoronix Media / Michael Larabel).

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

class ionity implements pts_option_interface
{
	const doc_section = 'Ionity Bench';
	const doc_description = 'This option shows the Ionity Bench banner together with the Ionity-authored benchmark suites and test profiles bundled in this release. Run any of them with: phoronix-test-suite benchmark ionity/<name> (or ionity-bench <name>).';

	public static function command_aliases()
	{
		return array('ionity_bench', 'ionity_info', 'ib');
	}
	public static function run($r)
	{
		echo PHP_EOL . pts_client::cli_just_bold(pts_core::ionity_banner()) . PHP_EOL;
		echo pts_client::cli_just_italic('Engine: ' . pts_core::engine_title() . ' (' . PTS_CODENAME . ') | GPL-3.0-or-later | ' . IONITY_BENCH_ORG . ' | Policy 986 AED') . PHP_EOL . PHP_EOL;

		$repo = IONITY_BENCH_REPOSITORY_ID;

		pts_client::$display->generic_heading('Ionity Suites');
		$rows = array();
		foreach(pts_file_io::glob(PTS_TEST_SUITE_PATH . $repo . '/*/suite-definition.xml') as $path)
		{
			$identifier = $repo . '/' . basename(dirname($path));
			$suite = new pts_test_suite($identifier);
			$rows[] = array(' ' . $identifier, pts_client::cli_just_bold($suite->get_title()), $suite->get_suite_type(), pts_strings::plural_handler(count($suite->get_contained_test_result_objects()), 'test'));
		}
		sort($rows);
		echo count($rows) > 0 ? pts_user_io::display_text_table($rows) . PHP_EOL . PHP_EOL : 'No Ionity suites found on disk.' . PHP_EOL . PHP_EOL;

		pts_client::$display->generic_heading('Ionity Test Profiles');
		$rows = array();
		foreach(pts_file_io::glob(PTS_TEST_PROFILE_PATH . $repo . '/*/test-definition.xml') as $path)
		{
			$identifier = $repo . '/' . basename(dirname($path));
			$tp = new pts_test_profile($identifier);
			$rows[] = array(' ' . $identifier, pts_client::cli_just_bold($tp->get_title()), $tp->get_test_hardware_type(), $tp->get_result_scale());
		}
		sort($rows);
		echo count($rows) > 0 ? pts_user_io::display_text_table($rows) . PHP_EOL . PHP_EOL : 'No Ionity test profiles found on disk.' . PHP_EOL . PHP_EOL;

		echo pts_client::cli_just_bold('Quick start:') . PHP_EOL;
		echo '  ionity-bench quick-check          # ~5 minute smoke test of the Ionity core benches' . PHP_EOL;
		echo '  ionity-bench edge-node            # Raspberry Pi / Radxa / SBC class edge node profile' . PHP_EOL;
		echo '  ionity-bench iot-gateway          # Telemetry, MQTT-style JSON, crypto, loopback networking' . PHP_EOL;
		echo '  phoronix-test-suite info ionity/io-core' . PHP_EOL . PHP_EOL;
		echo IONITY_BENCH_REPO . ' | ' . IONITY_BENCH_URL . ' | ai@ionity.today' . PHP_EOL . PHP_EOL;
	}
}

?>
