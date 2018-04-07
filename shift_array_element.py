#This script rotate integer array elements by shift 
# Ex. : 
# input :  3 10,11,14,15
#output :  11,14,15,10
 
import sys

def arrayShift(argv):
        arg1 = int(sys.argv[1])
        arg2 = sys.argv[2]
        list = arg2.split(',');
        list = map(int, list);
        
	n = len(list);

        shift = n-arg1;
        
        output = list[shift:n] + list[0:shift];
	print('Output : ', output);	 
	

if __name__ == "__main__":		 
    arrayShift(sys.argv[1:])
