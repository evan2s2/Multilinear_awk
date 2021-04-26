#!/bin/bash
clear

# file should include only 1 value for prediction as the last column

input_file_train='Fe_train.dat' ; echo train sample: $input_file_train
#input_file_train='input_train.dat' ; echo train sample: $input_file_train
input_file_test='Fe_test.dat' ; echo test sample: $input_file_test
#input_file_test='input_test.dat' ; echo test sample: $input_file_test

output_test_values='output_test_values.dat' 
output_file='output.dat'
output_figure='fit.png'
echo Wait please ...
#----------------------------------------------------------------------
###############
#             #
#     FIT     #
#             # 
###############
#----------------------------------------------------------------------
# get feature vector dimension
f_vec_dim=($(cat $input_file_train | awk '{print NF-1}')[0])
#----------------------------------------------------------------------
# get y_train & y_train_mean
y=($(cat $input_file_train | awk '{print $NF}'))
y_mean=$(echo ${y[@]} | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s/NF}')
#----------------------------------------------------------------------
# function for getting weight for a single feature
get_weight(){
	x=($(cat $input_file_train | awk -v i=$i '{print $i}'))
	x_mean=$(echo ${x[@]} | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s/NF}')
	#----------------------------------------------------------------------
	# covariance
	covar=0
	for i in ${!x[@]} ; do
		tmp=0
		tmp=$(echo ${x[$i]} ${y[$i]} | awk -v x_m=$x_mean -v y_m=$y_mean '{print ($1 - x_m)*($2 - y_m)}')
		covar=$(echo $tmp $covar | awk '{print $1+$2}')
	done
	#echo covariance = $covar # DEBUG
	#----------------------------------------------------------------------
	# variance
	var=0
	for i in ${!x[@]} ; do
		tmp=0
		tmp=$(echo ${x[$i]} | awk -v x_m=$x_mean '{print (($1 - x_m)^2)}')
		var=$(echo $tmp $var | awk '{print $1+$2}')
	done
	#echo variance = $var # DEBUG
	#----------------------------------------------------------------------
	# coefficients
	w=$(echo $covar $var | awk '{print $1/$2}')
	echo $w # equal to python's return 
}
#----------------------------------------------------------------------
# bias calculation
## get weights array with dimension of f_vec_dim=features vector dimension
for i in $(seq 1 1 $f_vec_dim) ; do
	weights_array+=($(get_weight))
done
echo "weights(wi) = [${weights_array[@]}]" > $output_file

#  get bias
## define function to make summation of x_mean vs weight of single x feature 
single_feature_wi_xi(){ #function of i = number of the feature
	x=($(cat $input_file_train | awk -v i=$i '{print $i}'))
	x_mean=$(echo ${x[@]} | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s/NF}')
	wi=$(echo ${weights_array[$(echo $i-1 | bc)]})
	wi_xi=$(echo $x_mean $wi | awk '{print $1*$2}')
	#wi_xi=$(echo ${x[@]} | awk -v wi=$wi '{s=0; for(i=1;i<=NF;i++) s+=$i*wi; print s}')
	echo $wi_xi
}

## get array of wi*xi_mean where i is a number of feature
for i in $(seq 1 1 $f_vec_dim) ; do
	wi_xi_mean_array+=($(single_feature_wi_xi))
done
echo "array(mean(xi)*wi) = [${wi_xi_mean_array[@]}]" >> $output_file

## sum of wi*xi_mean
sum_mean_xi_wi=$(echo ${wi_xi_mean_array[@]} | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s}')
echo "sum(mean(xi)*wi) = $sum_mean_xi_wi" >> $output_file

## get bias
bias=$(echo $y_mean $sum_mean_xi_wi | awk '{print $1-$2}')
echo bias = $bias >> $output_file
#----------------------------------------------------------------------
echo Fitting completed!
echo Wait please for estimation ...
#----------------------------------------------------------------------

######################
#                    #
#        MODEL       #
#     ESTIMATION     #
#                    # 
######################
#----------------------------------------------------------------------
# get y_pred for train sample and define r2 score of training process
echo "" >> $output_file
echo Training estimation: >> $output_file
c=0 # line counter

# r2 members
y_true_minus_y_pred_array=()
y_true_minus_y_mean=()

# inline estimation of input_train_file
while read LINE ; do
	c=$(echo "($c+1)" | bc)
	xi_wi=()
	for i in ${!weights_array[@]} ; do
		wi=${weights_array[$i]}
		xi_wi+=($(echo $LINE | awk -v i=$i -v wi=$wi '{print $(i+1)*wi}')) # an array of xi*wi products for a single x vector
	done
	sum_xi_wi=$(echo ${xi_wi[@]} | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s}')
	add_bias=$(echo $sum_xi_wi $bias | awk '{print $1+$2}') # y_pred
	#echo "	y_pred_$c = $add_bias" # DEBUG
	y_train=$(echo $LINE | awk '{print $NF}') # y_true
	y_true_minus_y_pred_array+=($(echo $y_train $add_bias | awk '{print ($1-$2)^2}'))
	y_true_minus_y_mean+=($(echo $y_train $y_mean | awk '{print ($1-$2)^2}'))
done < $input_file_train

# get sum of r2 members
up=$(echo ${y_true_minus_y_pred_array[@]} | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s}')
down=$(echo ${y_true_minus_y_mean[@]} | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s}')

echo R2_train = $(echo $up $down | awk '{print 1-$1/$2}') >> $output_file
#----------------------------------------------------------------------

######################
#                    #
#        MODEL       #
#        TEST        #
#                    # 
######################
#----------------------------------------------------------------------
echo "" >> $output_file
echo Testing estimation: >> $output_file

# get y_test & y_test_mean
y=($(cat $input_file_test | awk '{print $NF}'))
y_test_mean=$(echo ${y[@]} | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s/NF}')

c=0 # line counter

# r2 members
y_test_minus_y_pred_array=()
y_test_minus_y_mean_array=()

# inline estimation of input_test_file
if test -f $output_test_values ; then rm $output_test_values ; fi
while read LINE ; do
	c=$(echo "($c+1)" | bc)
	xi_wi=()
	for i in ${!weights_array[@]} ; do
		wi=${weights_array[$i]}
		xi_wi+=($(echo $LINE | awk -v i=$i -v wi=$wi '{print $(i+1)*wi}')) # an array of xi*wi products for a single x vector
	done
	sum_xi_wi=$(echo ${xi_wi[@]} | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s}')
	y_pred=$(echo $sum_xi_wi $bias | awk '{print $1+$2}') # y_pred
	#echo "	y_pred_$c = $y_pred" # DEBUG
	y_test=$(echo $LINE | awk '{print $NF}') # y_true
	echo $y_test $y_pred >> $output_test_values
	y_test_minus_y_pred_array+=($(echo $y_test $y_pred | awk '{print ($1-$2)^2}'))
	y_test_minus_y_mean_array+=($(echo $y_test $y_test_mean | awk '{print ($1-$2)^2}'))
done < $input_file_test

# get sum of r2 members
up=$(echo ${y_test_minus_y_pred_array[@]} | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s}')
down=$(echo ${y_test_minus_y_mean_array[@]} | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s}')

R2_test=$(echo $up $down | awk '{print 1-$1/$2}')
echo R2_test = $R2_test >> $output_file
#----------------------------------------------------------------------
echo ------------------------------------------------
echo output file: $output_file
echo output testvalues file: $output_test_values
echo ------------------------------------------------
cat $output_file

echo See $output_test_values file for more
echo ------------------------------------------------
echo output figure: $output_figure
echo ------------------------------------------------

# plot
y_test_array=($(awk '{print $1}' $output_test_values)) 
max_value_y_pred=$(echo ${y_test_array[@]} | awk '{	{for(i=1;i<=NF;i++) { if( MAX == "" || $i > MAX ) { MAX=$i } }}	{print MAX}}')

y_train_array=($(awk '{print $2}' $output_test_values)) 
max_value_y_train=$(echo ${y_train_array[@]} | awk '{	{for(i=1;i<=NF;i++) { if( MAX == "" || $i > MAX ) { MAX=$i } }}	{print MAX}}')

max_dimension=$(echo $max_value_y_pred $max_value_y_train | awk '{	{for(i=1;i<=NF;i++) { if( MAX == "" || $i > MAX ) { MAX=$i } }}	{print MAX}}')
echo 0 0 > tmp_file.dat 
echo $max_dimension $max_dimension >> tmp_file.dat

gnuplot << plot
##! /usr/bin/gnuplot -persist'
set term png
set output "output_figure.png"
set xlabel "True value"
set ylabel "Predicted value"
plot 	"$output_test_values" using 1:2 title "Test R2 = $R2_test" w p pt 7 ps 1, \
		"tmp_file.dat" using 1:2 title "" w l
plot

if test -f tmp_file.dat	; then rm tmp_file.dat ; fi

model_predict(){
	echo Wait please ...
	c=0
	while read LINE ; do
		c=$(echo "($c+1)" | bc)
		xi_wi=()
		for i in ${!weights_array[@]} ; do
			wi=${weights_array[$i]}
			xi_wi+=($(echo $LINE | awk -v i=$i -v wi=$wi '{print $(i+1)*wi}')) # an array of xi*wi products for a single x vector
		done
		sum_xi_wi=$(echo ${xi_wi[@]} | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s}')
		y_pred=$(echo $sum_xi_wi $bias | awk '{print $1+$2}') # y_pred
		echo "	y_pred_$c = $y_pred" >> $output_file
	done 
	echo See $output_file for results
}

# function for predicting
#model_predict < $your_file # uncomment if necessary
