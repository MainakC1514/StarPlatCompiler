// FOR BC: nvcc bc_dsl_v2.cu -arch=sm_60 -std=c++14 -rdc=true # HW must support CC 6.0+ Pascal or after
#include "graphColoring.h"

void colorGraph(graph& g)

{
  // CSR BEGIN
  int V = g.num_nodes();
  int E = g.num_edges();

  printf("#nodes:%d\n",V);
  printf("#edges:%d\n",E);
  int* edgeLen = g.getEdgeLen();

   FILE* fptr = fopen("num_devices.txt","r"); 
  int devicecount;
   if(fptr == NULL){ 
     cudaGetDeviceCount(&devicecount); 
     } 
   else{ 
     fscanf(fptr," %d ",&devicecount); 
     fclose(fptr); 
  }
  int* h_vertex_partition;
  int *h_edges;//data
  int *h_weight;
  int *h_offset;//meta
  int* h_src;
  int *h_rev_meta;
  int h_vertex_per_device;

  h_edges = (int *)malloc( (E)*sizeof(int));
  h_weight = (int *)malloc( (E)*sizeof(int));
  h_offset = (int *)malloc( (V+1)*sizeof(int));
  h_src = (int *)malloc( (E)*sizeof(int));
  h_vertex_partition = (int*)malloc((devicecount+1)*sizeof(int));
  h_rev_meta = (int *)malloc( (V+1)*sizeof(int));
  h_vertex_per_device = V/devicecount;

  for(int i=0; i<= V; i++) {
    h_offset[i] = g.indexofNodes[i];
    h_rev_meta[i] = g.rev_indexofNodes[i];
  }

  int index = 0;
  h_vertex_partition[0]=0;
  h_vertex_partition[devicecount]=V;
  for(int i=1;i<devicecount;i++){
    if(i<=(V%devicecount)){
       index+=(h_vertex_per_device+1);
    }
    else{
       index+=h_vertex_per_device;
    }
    h_vertex_partition[i]=index;
  }
  for(int i=0; i< E; i++){
    h_edges[i]= g.edgeList[i];
    h_src[i]=g.srcList[i];
    h_weight[i] = edgeLen[i];
  }


  int** d_offset;
  int** d_edges;
  int** d_weight;
  int** d_src;
  int** d_rev_meta;
  d_offset = (int**) malloc(devicecount*sizeof(int*));
  d_edges = (int**) malloc(devicecount*sizeof(int*));
  d_weight = (int**) malloc(devicecount*sizeof(int*));
  d_src = (int**) malloc(devicecount*sizeof(int*));
  d_rev_meta = (int**) malloc(devicecount*sizeof(int*));

  int perdevicevertices;
  int lastleftvertices;
  perdevicevertices = V / devicecount ;
  lastleftvertices = V % devicecount;
  for(int i=0;i<devicecount;i++)	
  {
    cudaSetDevice(i);
    cudaMalloc(&d_offset[i], (V+1)*sizeof(int) );
    cudaMalloc(&d_edges[i], (E)*sizeof(int) );
    cudaMalloc(&d_weight[i], (E)*sizeof(int) );
    cudaMalloc(&d_src[i], (E)*sizeof(int) );
    cudaMalloc(&d_rev_meta[i], (V+1)*sizeof(int) );
  }
  for(int i=0;i<devicecount;i++)	
  {
    cudaSetDevice(i);
    cudaMemcpyAsync(d_offset[i], h_offset, (V+1)*sizeof(int),cudaMemcpyHostToDevice);
    cudaMemcpyAsync(d_edges[i], h_edges, (E)*sizeof(int),cudaMemcpyHostToDevice);
    cudaMemcpyAsync(d_weight[i], h_weight, (E)*sizeof(int),cudaMemcpyHostToDevice );
    cudaMemcpyAsync(d_src[i], h_src, (E)*sizeof(int),cudaMemcpyHostToDevice );
    cudaMemcpyAsync(d_rev_meta[i], h_rev_meta, (V+1)*sizeof(int),cudaMemcpyHostToDevice );
  }
  for(int i=0;i<devicecount;i++)	
  {
    cudaSetDevice(i);
    cudaDeviceSynchronize();
  }

  const unsigned threadsPerBlock = 1024;
  unsigned numThreads   = (V < threadsPerBlock)? V: 1024;
  unsigned numBlocks    = (V+threadsPerBlock-1)/threadsPerBlock;


  // TIMER START
  cudaEvent_t start, stop;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  float milliseconds = 0;
  cudaEventRecord(start,0);


  //DECLARE DEVICE AND HOST vars in params

  //BEGIN DSL PARSING 
  long** h_color;
  h_color = (long**)malloc(sizeof(long*)*(devicecount+1));
  for(int i=0;i<=devicecount;i++){
    h_color[i]=(long*)malloc(sizeof(long)*(V+1));
  }
  long** d_color;
  d_color = (long**)malloc(sizeof(long*)*devicecount);
  for (int i = 0; i < devicecount; i++) {
    cudaSetDevice(i);
    cudaMalloc(&d_color[i], sizeof(long)*(V+1));
  }

  long* h_color_temp1 = (long*)malloc((V+1)*(devicecount)*sizeof(long));
  cudaSetDevice(0);
  long* d_color_temp1;
  cudaMalloc(&d_color_temp1,(V+1)*(devicecount)*sizeof(long));
  long* d_color_temp2;
  cudaMalloc(&d_color_temp2,(V+1)*(devicecount)*sizeof(long));


  int** h_color1;
  h_color1 = (int**)malloc(sizeof(int*)*(devicecount+1));
  for(int i=0;i<=devicecount;i++){
    h_color1[i]=(int*)malloc(sizeof(int)*(V+1));
  }
  int** d_color1;
  d_color1 = (int**)malloc(sizeof(int*)*devicecount);
  for (int i = 0; i < devicecount; i++) {
    cudaSetDevice(i);
    cudaMalloc(&d_color1[i], sizeof(int)*(V+1));
  }

  int* h_color1_temp1 = (int*)malloc((V+1)*(devicecount)*sizeof(int));
  cudaSetDevice(0);
  int* d_color1_temp1;
  cudaMalloc(&d_color1_temp1,(V+1)*(devicecount)*sizeof(int));
  int* d_color1_temp2;
  cudaMalloc(&d_color1_temp2,(V+1)*(devicecount)*sizeof(int));


  int** h_color2;
  h_color2 = (int**)malloc(sizeof(int*)*(devicecount+1));
  for(int i=0;i<=devicecount;i++){
    h_color2[i]=(int*)malloc(sizeof(int)*(V+1));
  }
  int** d_color2;
  d_color2 = (int**)malloc(sizeof(int*)*devicecount);
  for (int i = 0; i < devicecount; i++) {
    cudaSetDevice(i);
    cudaMalloc(&d_color2[i], sizeof(int)*(V+1));
  }

  int* h_color2_temp1 = (int*)malloc((V+1)*(devicecount)*sizeof(int));
  cudaSetDevice(0);
  int* d_color2_temp1;
  cudaMalloc(&d_color2_temp1,(V+1)*(devicecount)*sizeof(int));
  int* d_color2_temp2;
  cudaMalloc(&d_color2_temp2,(V+1)*(devicecount)*sizeof(int));


  bool** h_modified;
  h_modified = (bool**)malloc(sizeof(bool*)*(devicecount+1));
  for(int i=0;i<=devicecount;i++){
    h_modified[i]=(bool*)malloc(sizeof(bool)*(V+1));
  }
  bool** d_modified;
  d_modified = (bool**)malloc(sizeof(bool*)*devicecount);
  for (int i = 0; i < devicecount; i++) {
    cudaSetDevice(i);
    cudaMalloc(&d_modified[i], sizeof(bool)*(V+1));
  }

  bool* h_modified_temp1 = (bool*)malloc((V+1)*(devicecount)*sizeof(bool));
  cudaSetDevice(0);
  bool* d_modified_temp1;
  cudaMalloc(&d_modified_temp1,(V+1)*(devicecount)*sizeof(bool));
  bool* d_modified_temp2;
  cudaMalloc(&d_modified_temp2,(V+1)*(devicecount)*sizeof(bool));


  bool** h_modified_next;
  h_modified_next = (bool**)malloc(sizeof(bool*)*(devicecount+1));
  for(int i=0;i<=devicecount;i++){
    h_modified_next[i]=(bool*)malloc(sizeof(bool)*(V+1));
  }
  bool** d_modified_next;
  d_modified_next = (bool**)malloc(sizeof(bool*)*devicecount);
  for (int i = 0; i < devicecount; i++) {
    cudaSetDevice(i);
    cudaMalloc(&d_modified_next[i], sizeof(bool)*(V+1));
  }

  bool* h_modified_next_temp1 = (bool*)malloc((V+1)*(devicecount)*sizeof(bool));
  cudaSetDevice(0);
  bool* d_modified_next_temp1;
  cudaMalloc(&d_modified_next_temp1,(V+1)*(devicecount)*sizeof(bool));
  bool* d_modified_next_temp2;
  cudaMalloc(&d_modified_next_temp2,(V+1)*(devicecount)*sizeof(bool));


  int fpoint1 = 0; // asst in .cu 
  int** h_fpoint1;
  h_fpoint1 = (int**)malloc(sizeof(int*)*(devicecount+1));
  for(int i=0;i<=devicecount;i+=1){
    h_fpoint1[i] = (int*)malloc(sizeof(int));
  }

  int** d_fpoint1;
  d_fpoint1 = (int**)malloc(sizeof(int*)*devicecount);
  for(int i = 0 ; i < devicecount ; i++){
    cudaSetDevice(i);
    cudaMalloc(&d_fpoint1[i],sizeof(int));
    initKernel<int> <<<1,1>>>(1,d_fpoint1[i],0);
    cudaDeviceSynchronize();
  }


  int numNodes = g.num_nodes(); // asst in .cu 
  int** h_numNodes;
  h_numNodes = (int**)malloc(sizeof(int*)*(devicecount+1));
  for(int i=0;i<=devicecount;i+=1){
    h_numNodes[i] = (int*)malloc(sizeof(int));
  }

  int** d_numNodes;
  d_numNodes = (int**)malloc(sizeof(int*)*devicecount);
  for(int i = 0 ; i < devicecount ; i++){
    cudaSetDevice(i);
    cudaMalloc(&d_numNodes[i],sizeof(int));
    initKernel<int> <<<1,1>>>(1,d_numNodes[i],g.num_nodes( ));
    cudaDeviceSynchronize();
  }


  int iter = 0; // asst in .cu 
  int** h_iter;
  h_iter = (int**)malloc(sizeof(int*)*(devicecount+1));
  for(int i=0;i<=devicecount;i+=1){
    h_iter[i] = (int*)malloc(sizeof(int));
  }

  int** d_iter;
  d_iter = (int**)malloc(sizeof(int*)*devicecount);
  for(int i = 0 ; i < devicecount ; i++){
    cudaSetDevice(i);
    cudaMalloc(&d_iter[i],sizeof(int));
    initKernel<int> <<<1,1>>>(1,d_iter[i],0);
    cudaDeviceSynchronize();
  }


  do{
    iter = iter + 1;
    for(int i=0;i<devicecount;i++){
      cudaSetDevice(i);
      //printed here

      initKernel<int> <<<1,1>>>(1,d_iter[i],(int)iter + 1);
      cudaDeviceSynchronize();
    }
    int x1=rand();
    for(int i=0;i<devicecount;i++){
      cudaSetDevice(i);
      curandGenerator_t gen;
      curandCreateGenerator(&gen,CURAND_RNG_PSEUDO_PHILOX4_32_10);
      curandSetPseudoRandomGeneratorSeed(gen,x1);
    }
    int x2=rand();
    for(int i=0;i<devicecount;i++){
      cudaSetDevice(i);
      curandGenerator_t gen;
      curandCreateGenerator(&gen,CURAND_RNG_PSEUDO_PHILOX4_32_10);
      curandSetPseudoRandomGeneratorSeed(gen,x2);
    }
    for(int i=0;i<devicecount;i++)
    {
      cudaSetDevice(i);
      colorGraph_kernel1<<<numBlocks, threadsPerBlock>>>(h_vertex_partition[i],h_vertex_partition[i+1],V,E,d_offset[i],d_edges[i],d_weight[i],d_src[i],d_rev_meta[i],d_modified[i],d_fpoint1[i],d_color[i],d_modified_next[i]);
    }

    for(int i=0;i<devicecount;i++)
    {
      cudaSetDevice(i);
      cudaDeviceSynchronize();
    }


    //v v
    for(int i=0;i<devicecount;i++){
      cudaSetDevice(i);
      cudaMemcpyAsync(h_modified_next[devicecount]+h_vertex_partition[i],d_modified_next[i]+h_vertex_partition[i],sizeof(bool)*(h_vertex_partition[i+1]-h_vertex_partition[i]),cudaMemcpyDeviceToHost);
      cudaDeviceSynchronize();
    }
    for(int i=0;i<devicecount;i++){
      cudaSetDevice(i);
      cudaMemcpyAsync(d_modified_next[i],h_modified_next[devicecount],sizeof(bool)*(V+1),cudaMemcpyHostToDevice);
      cudaDeviceSynchronize();
    }
    for(int i=0;i<devicecount;i++){
      cudaSetDevice(i);
      cudaMemcpyAsync(h_modified_next[i],d_modified_next[i],sizeof(bool)*(V+1),cudaMemcpyDeviceToHost);
      cudaDeviceSynchronize();
    }
    for(int i=0;i<devicecount;i++){
      fpoint1 += h_fpoint1[i][0];
    } //end of for
    cudaMemcpy(d_modified, d_modified_next, sizeof(bool)*V, cudaMemcpyDeviceToDevice);
  }while(fpoint1 < numNodes);
  //TIMER STOP
  cudaEventRecord(stop,0);
  cudaEventSynchronize(stop);
  cudaEventElapsedTime(&milliseconds, start, stop);
  printf("GPU Time: %.6f ms\n", milliseconds);

} //end FUN
