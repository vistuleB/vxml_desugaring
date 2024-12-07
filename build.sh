#!/bin/bash
gleam build
gleam run -m gleescript

rm -r ../../Devland-agancy/little-bo-peep-leptos/parser
mv ./lbp_desugaring ../../Devland-agancy/little-bo-peep-leptos/parser