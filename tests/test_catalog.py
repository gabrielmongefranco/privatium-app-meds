#!/usr/bin/env python3
# This file is part of Prescription Tracker
# tests/test_catalog.py
# Author(s): Gabriel Mongefranco
# Created: 2026-10-01
# Last Modified: 2026-10-01
# Summary: Checks public catalog marks against invented reference responses.
# Notes: See README file for documentation and full license information.
#
# Copyright © 2026 Gabriel Mongefranco
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

import importlib.util
import pathlib
import unittest
from unittest import mock

SOURCE = pathlib.Path(__file__).resolve().parents[1] / 'tools/build_seed.py'
SPEC = importlib.util.spec_from_file_location('build_seed', SOURCE)
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class CatalogMarkTests(unittest.TestCase):
    """Check controlled and specialty suggestions without making network requests."""

    def test_only_recognized_schedules_mark_linked_products(self):
        reference = BUILDER.Reference.__new__(BUILDER.Reference)
        reference.get = mock.Mock(return_value={'results': [
            {'dea_schedule': 'CII', 'openfda': {'rxcui': ['111', '222']}},
            {'dea_schedule': 'CV', 'openfda': {'rxcui': ['333']}},
            {'dea_schedule': 'Untrusted text', 'openfda': {'rxcui': ['444']}},
            {'openfda': {'rxcui': ['555']}},
            {'dea_schedule': 'CIII'},
        ]})
        self.assertEqual(reference.controlled_products('Example Ingredient'), {'111', '222', '333'})
        url = reference.get.call_args.args[0]
        self.assertTrue(url.startswith(BUILDER.OPENFDA_NDC + '?'))
        self.assertIn('limit=100', url)
        self.assertEqual(reference.get.call_args.kwargs, {'empty_status': 404})

    def test_missing_products_remain_unmarked(self):
        reference = BUILDER.Reference.__new__(BUILDER.Reference)
        reference.get = mock.Mock(return_value={})
        self.assertEqual(reference.controlled_products('Example Ingredient'), set())

    def test_specialty_name_suggestions(self):
        listed = {'somatropin', 'teriparatide', 'glatiramer', 'interferon'}
        for name in ['Specizumab', 'Examplecept', 'Somatropin', 'Interferon beta-1a',
                     'Glatiramer acetate', 'Example Ingredient / Teriparatide']:
            self.assertTrue(BUILDER.specialty_mark(name, listed), name)
        for name in ['', 'Lisinopril', 'Example Ingredient', 'Somatropinlike']:
            self.assertFalse(BUILDER.specialty_mark(name, listed), name)


if __name__ == '__main__':
    unittest.main()
