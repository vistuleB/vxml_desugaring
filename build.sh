#!/bin/bash
gleam build
gleam run -m gleescript

rm -r ../../Devland-agancy/little-bo-peep-leptos/parser
rm -r ../../MrChaker/little-bo-peep-solid/parser_script

cp ./lbp_desugaring ../../Devland-agancy/little-bo-peep-leptos/parser
mv ./lbp_desugaring ../../MrChaker/little-bo-peep-solid/parser_script
