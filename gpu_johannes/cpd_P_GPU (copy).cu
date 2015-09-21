/*
Andriy Myronenko
 */


#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include "mex.h"
#include <cuda_runtime.h>
#include "cublas_v2.h"

#define	max(A, B)	((A) > (B) ? (A) : (B))
#define	min(A, B)	((A) < (B) ? (A) : (B))

__global__
void magickernel(
		double* d_x,
		double* d_y, 
        double d_sigma2,
		double d_outlier,
        double* d_P1,
        double* d_Pt1,
        double* d_Px,
    	double* d_E,
        int d_N,
		int d_M,
        int d_D,
        double* d_P,
		double* temp_x
        ) {
    //int x = threadIdx.x + blockDim.x * blockIdx.x;
    //int y = threadIdx.y + blockDim.y * blockIdx.y;
//    int z = threadIdx.z + blockDim.z * blockIdx.z;
    
    
    //int index = x + y;
    
    int		n, m, d;
    double	ksig, diff, razn, outlier_tmp, sp;
//    double	*d_P, *temp_x;
    
//    double d_P[d_M];
//    double temp_x[d_D];
    
//    d_P = (double*) calloc(d_M, sizeof(double));
//    temp_x = (double*) calloc(d_D, sizeof(double));
 
//    cudaMalloc(&d_P,d_M * sizeof(double));
//    cudaMalloc(&temp_x,d_D * sizeof(double));

    

    
    ksig = -2.0 * d_sigma2;

    outlier_tmp=(d_outlier*d_M*pow(-ksig*3.14159265358979,0.5*d_D))/((1-d_outlier)*d_N); 
    
     /* printf ("ksig = %lf\n", *sigma2);*/
      /* outlier_tmp=*outlier*N/(1- *outlier)/M*(-ksig*3.14159265358979); */
      
      
      for (n=0; n < d_N; n++) {
          
          sp=0;
          for (m=0; m < d_M; m++) {
              razn=0;
              for (d=0; d < d_D; d++) {
                 diff=d_x[n+d*d_N]-d_y[m+d*d_M];  
                 diff=diff*diff;
                 razn+=diff;
              }
              
              d_P[m]=exp(razn/ksig);
              sp+=d_P[m];
          }
          
          sp+=outlier_tmp;
          d_Pt1[n]=1-outlier_tmp/ sp;
          
          for (d=0; d < d_D; d++) {
           temp_x[d]=d_x[n+d*d_N]/ sp;
          }
             
          for (m=0; m < d_M; m++) {
             
              d_P1[m]+=d_P[m]/ sp;
              
              for (d=0; d < d_D; d++) {
              d_Px[m+d*d_M]+= temp_x[d]*d_P[m];
              }
              
          }
          
       *d_E +=  -log(sp);     
      }
      *d_E +=d_D*d_N*log(d_sigma2)/2;
        
      
//      free((void*)P);
//      free((void*)temp_x);
    
}

void cpd_comp(
		double* x,
		double* y, 
        double* sigma2,
		double* outlier,
        double* P1,
        double* Pt1,
        double* Px,
    	double* E,
        int N,
		int M,
        int D
        )

{
  int		n, m, d;
  double	ksig, diff, razn, outlier_tmp, sp;
  double	*P, *temp_x;
  
//  P = (double*) calloc(M, sizeof(double));
//  temp_x = (double*) calloc(D, sizeof(double));
  
  ksig = -2.0 * *sigma2;
  outlier_tmp=(*outlier*M*pow (-ksig*3.14159265358979,0.5*D))/((1-*outlier)*N); 
 /* printf ("ksig = %lf\n", *sigma2);*/
  /* outlier_tmp=*outlier*N/(1- *outlier)/M*(-ksig*3.14159265358979); */
  
  
  for (n=0; n < N; n++) {
      
      sp=0;
      for (m=0; m < M; m++) {
          razn=0;
          for (d=0; d < D; d++) {
             diff=*(x+n+d*N)-*(y+m+d*M);  diff=diff*diff;
             razn+=diff;
          }
          
          *(P+m)=exp(razn/ksig);
          sp+=*(P+m);
      }
      
      sp+=outlier_tmp;
      *(Pt1+n)=1-outlier_tmp/ sp;
      
      for (d=0; d < D; d++) {
       *(temp_x+d)=*(x+n+d*N)/ sp;
      }
         
      for (m=0; m < M; m++) {
         
          *(P1+m)+=*(P+m)/ sp;
          
          for (d=0; d < D; d++) {
          *(Px+m+d*M)+= *(temp_x+d)**(P+m);
          }
          
      }
      
   *E +=  -log(sp);     
  }
  *E +=D*N*log(*sigma2)/2;
    
  
  free((void*)P);
  free((void*)temp_x);

  return;
}

/* Input arguments */
#define IN_x		prhs[0] //double array
#define IN_y		prhs[1] //double array
#define IN_sigma2	prhs[2] //double scalar
#define IN_outlier	prhs[3] //double scalar


/* Output arguments */
#define OUT_P1		plhs[0] //double array
#define OUT_Pt1		plhs[1] //double array
#define OUT_Px		plhs[2] //double array
#define OUT_E		plhs[3] //double scalar


/* Gateway routine */
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[] )
{
  double *x, *y, *sigma2, *outlier, *P1, *Pt1, *Px, *E;
  int     N, M, D;
  
  /* Get the sizes of each input argument */
  N = mxGetM(IN_x); //Number of rows in array
  M = mxGetM(IN_y);
  D = mxGetN(IN_x); //Number of columns in array
  
  /* Create the new arrays and set the output pointers to them */
  OUT_P1     = mxCreateDoubleMatrix(M, 1, mxREAL);
  OUT_Pt1    = mxCreateDoubleMatrix(N, 1, mxREAL);
  OUT_Px    = mxCreateDoubleMatrix(M, D, mxREAL);
  OUT_E       = mxCreateDoubleMatrix(1, 1, mxREAL);

    /* Assign pointers to the input arguments */
  x      = mxGetPr(IN_x);
  y       = mxGetPr(IN_y);
  sigma2       = mxGetPr(IN_sigma2);
  outlier    = mxGetPr(IN_outlier);

 
  
  /* Assign pointers to the output arguments */
  P1      = mxGetPr(OUT_P1); 
  Pt1      = mxGetPr(OUT_Pt1);
  Px      = mxGetPr(OUT_Px);
  E     = mxGetPr(OUT_E);
   
  float res[1];
  res[0] = 0;
  
  float* d_res;
  cudaMalloc(&d_res,1 * sizeof(float));
  
  //allocate memory on GPU
  double* d_x;
  double* d_y;
//  double d_sigma2;
//  double d_outlier;
  double* d_P1;
  double* d_Pt1;
  double* d_Px;
  double* d_E;
//  double* d_N;
//  double* d_M;
//  double* d_D;
  double* d_P;
  double* temp_x;
  
  cudaMalloc(&d_x,M * sizeof(double));
  cudaMalloc(&d_y,N * sizeof(double));
  cudaMalloc(&d_P1,M * sizeof(double));
  cudaMalloc(&d_Pt1,N  * sizeof(double));
  cudaMalloc(&d_Px,M*D * sizeof(double));
  cudaMalloc(&d_E,1 * sizeof(double));

  cudaMalloc(&d_P,M * sizeof(double));
  cudaMalloc(&temp_x,D * sizeof(double));
  
  cudaMemcpy(d_x, x, M * sizeof(double), cudaMemcpyHostToDevice);
  cudaMemcpy(d_y, y, N * sizeof(double), cudaMemcpyHostToDevice);
  cudaMemcpy(d_P1, P1, M * sizeof(double), cudaMemcpyHostToDevice);
  cudaMemcpy(d_Pt1, Pt1, N * sizeof(double), cudaMemcpyHostToDevice);
  cudaMemcpy(d_Px, Px, M*D * sizeof(double), cudaMemcpyHostToDevice);
  cudaMemcpy(d_E, E, 1 * sizeof(double), cudaMemcpyHostToDevice);

  
//  cudaMemcpy(d_res, res, sizeof(float), cudaMemcpyHostToDevice);

  dim3 block = dim3(128, 8);
  dim3 grid = dim3((D + block.x - 1) / block.x,
			(M + block.y - 1) / block.y);
  
  magickernel <<<grid, block>>> (d_x, d_y, *sigma2, *outlier, d_P1, d_Pt1, d_Px, d_E, N, M, D, d_P, temp_x);
  
//  cudaMemcpy(res, d_res, sizeof(float), cudaMemcpyDeviceToHost);
  cudaMemcpy(P1, d_P1, M * sizeof(double), cudaMemcpyDeviceToHost);
  cudaMemcpy(Pt1, d_Pt1, N * sizeof(double), cudaMemcpyDeviceToHost);
  cudaMemcpy(Px, d_Px, M*D * sizeof(double), cudaMemcpyDeviceToHost);
  cudaMemcpy(E, d_E, 1 * sizeof(double), cudaMemcpyDeviceToHost);
  
  cudaFree(d_x);
  cudaFree(d_y);
  cudaFree(d_P1);
  cudaFree(d_Pt1);
  cudaFree(d_Px);
  cudaFree(d_E);
  cudaFree(d_P);
  cudaFree(temp_x);
  
  mexPrintf("it worked: %f \n",res[0]);
  
  
  /* Do the actual computations in a subroutine */
//  cpd_comp(x, y, sigma2, outlier, P1, Pt1, Px, E, N, M, D);
  
  return;
}

