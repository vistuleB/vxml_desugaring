#!/bin/bash
gleam build
gleam run -m gleescript

rm -r ../little-bo-peep-leptos/parser
mv ./lbp_desugaring ../little-bo-peep-leptos/parser