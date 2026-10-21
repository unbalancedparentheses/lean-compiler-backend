typedef struct {float value;} Single;
extern float exact_fp_capacity(double,double,double,double,double,double,double,Single);
int main(void) {
    return exact_fp_capacity(1,2,3,4,5,6,7,(Single){3.25f}) == 3.25f ? 0 : 1;
}
