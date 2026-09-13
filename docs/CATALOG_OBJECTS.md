<!--
MIT License

Copyright (c) 2026 mr-highball

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
-->
# Optional object admission batch

This bounded batch adds twelve leaf models from the existing verified library.
It does not declare the full catalog complete. `phanes.catalog.objects` owns
their immutable source identity, measured rendering cost, scale, and conservative
millimetre envelope. `phanes.catalog.admission` exposes them as interior-domain
optional records. Admission checks are distinct from rendered placement evidence.
The current integration candidate appends all fourteen interior admissions to
the shared contents catalog. Interior object controls provide compatible category,
subgroup and name/group search. Browsing does not mutate the world; choosing an
item uses the existing WFC placement, validation and optional-source publication
path. Shelf and bench objects offer both books and ornaments; food remains
restricted to the selected portion's role and actual plate support.

| ID | Name | Group / role | Envelope W×D×H mm | Triangles | Vertices | Texels |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `phanes.catalog.book.rpg-closed.v1` | Red field journal | Books / book | 54×180×241 | 284 | 852 | 0 |
| `phanes.catalog.artifact.scroll.v1` | Bound scroll | Artifacts / ornament | 148×26×24 | 956 | 2,868 | 0 |
| `phanes.catalog.artifact.crystal-green.v1` | Green crystal | Artifacts / ornament | 97×85×230 | 12 | 36 | 0 |
| `phanes.catalog.artifact.potion-cyan.v1` | Stoppered vial | Artifacts / ornament | 132×114×233 | 404 | 1,212 | 0 |
| `phanes.catalog.artifact.candle.v1` | Graveyard candle | Artifacts / ornament | 137×137×201 | 54 | 100 | 262,144 |
| `phanes.catalog.equipment.radio.v1` | Field radio | Equipment / ornament | 144×49×179 | 481 | 1,443 | 0 |
| `phanes.catalog.equipment.compass.v1` | Open compass | Equipment / ornament | 146×113×129 | 656 | 1,968 | 0 |
| `phanes.catalog.equipment.station-switch.v1` | Station control switch | Equipment / ornament | 101×26×201 | 18 | 28 | 262,144 |
| `phanes.catalog.food.bread-slice.v1` | Bread slice | Bread / bread | 49×41×5 | 116 | 154 | 262,144 |
| `phanes.catalog.food.strawberry.v1` | Strawberry | Fruit / fruit | 42×42×64 | 156 | 288 | 262,144 |
| `phanes.catalog.food.cheese-slice.v1` | Cheese slice | Cheese / cheese | 50×35×3 | 160 | 234 | 262,144 |
| `phanes.catalog.food.croissant.v1` | Croissant | Bread / bread | 50×28×21 | 132 | 396 | 0 |

The eight object records fit the 150×190×270 mm admission cap. Fruit and
cheese fit a 50×50×75 mm plate envelope; bread portions fit 50×95×75 mm.
The thin bread and cheese sources are admitted as individual served slices,
while the strawberry and croissant retain plausible single-item scale.

The batch adds 546,010 conservative staged source bytes, 3,429 triangles,
9,579 POSITION vertices, and 1,310,720 texture pixels. Together with the two
original interior records and eighteen regional records, the 32-model optional
set measures 1,838,347 source bytes, 11,623 triangles, 33,017 vertices, and
3,670,016 texels.

The native verifier binds every interior record to the publication descriptor,
manifest, root source hash, independent decoded geometry, Castle triangle and
bounds decode, POSITION accessor count, and original PNG dimensions. It also
requires each new source to provide a texture, vertex color, or non-neutral
material color. These checks establish admission evidence; they do not cover
browser rendering, world lifetime, placement policy, or full-catalog review.
