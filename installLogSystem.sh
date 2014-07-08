#!/bin/sh
#installLogSystem.sh
# Created on: May 25, 2014
#     Author: eozekes

cd ./Installation

bash ./installChefSystem.sh
bash ./uploadChefCookbooks.sh
bash ./uploadLogSystemCookbooks.sh
