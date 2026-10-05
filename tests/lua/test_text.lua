-- This file is part of Prescription Tracker
-- tests/lua/test_text.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-05
-- Summary: Unit tests for apps/meds/lib/text.lua.
-- Notes: See README file for documentation and full license information.
--
-- Copyright © 2026 Gabriel Mongefranco
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program. If not, see <https://www.gnu.org/licenses/>.

local text = require 'text'

return function(equal)
  equal('clean trims both ends', text.clean('  Alex Example  '), 'Alex Example')
  equal('clean joins runs of spaces', text.clean('Alex     Example'), 'Alex Example')
  equal('clean turns a line break into a space', text.clean('Alex\r\nExample'), 'Alex Example')
  equal('clean turns a tab into a space', text.clean('Alex\tExample'), 'Alex Example')
  equal('clean of an empty text is nil', text.clean(''), nil)
  equal('clean of spaces only is nil', text.clean('   \n '), nil)
  equal('clean of nil is nil', text.clean(nil), nil)
  equal('clean of a table is nil', text.clean({ 'x' }), nil)
  equal('clean keeps markup as text', text.clean('<b>x</b>'), '<b>x</b>')

  equal('length counts characters, not bytes', text.length('café'), 4)
  equal('length of bytes that are not UTF-8 is nil', text.length('\xff\xfe'), nil)

  equal('key ignores case', text.key('Z-PAK'), text.key('z-pak'))
  equal('key ignores punctuation', text.key('Z-Pak'), 'z pak')
  equal('key ignores extra spaces', text.key('  Z   Pak '), 'z pak')
  equal('key of nil is empty', text.key(nil), '')
  equal('key tells different names apart', text.key('Examplol') == text.key('Examplal'), false)

  --- A decimal number without the zeros that say nothing ---
  equal('a whole quantity', text.plain_number('30.000'), '30')
  equal('a part of a package', text.plain_number('2.500'), '2.5')
  equal('three places that count', text.plain_number('0.125'), '0.125')
  equal('a number with no point', text.plain_number('100'), '100')
  equal('a whole number that ends in zero', text.plain_number('30'), '30')
  equal('zero', text.plain_number('0.000'), '0')
  equal('nothing', text.plain_number(nil), nil)
  equal('plain letters stay as they are', text.url_encode('last-90-days'), 'last-90-days')
  equal('a space and an ampersand are encoded', text.url_encode('a b&c=d'), 'a%20b%26c%3Dd')
  equal('a letter beyond ASCII is encoded byte by byte', text.url_encode('é'), '%C3%A9')
  equal('nil encodes as nothing', text.url_encode(nil), '')
end
