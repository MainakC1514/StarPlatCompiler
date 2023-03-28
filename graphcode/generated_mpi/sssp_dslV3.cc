#include"sssp_dslV3.h"

void Compute_SSSP(Graph& g, NodeProperty<int>& dist, EdgeProperty<int>& weight, int src
  , boost::mpi::communicator world )
{
  NodeProperty<bool> modified;
  NodeProperty<bool> modified_nxt;
  dist.attachToGraph(&g, (int)INT_MAX);
  modified.attachToGraph(&g, (bool)false);
  modified_nxt.attachToGraph(&g, (bool)false);
  if(world.rank() == g.get_node_owner(src))
  {
    modified.setValue(src,true);
  }
  if(world.rank() == g.get_node_owner(src))
  {
    dist.setValue(src,0);
  }
  bool finished = false;
  while ( !finished )
  {
    std::vector<Property *> temp_properties = {(Property*)&modified_nxt};
    g.initialise_reduction(MPI_MIN, (Property*)&dist, temp_properties);
    world.barrier();
    for (int v = g.start_node(); v <= g.end_node(); v ++) 
    {
      if (modified.getValue(v) == true )
        {
        for (int nbr : g.getNeighbors(v)) 
        {
          Edge e = g.get_edge(v, nbr);
          g.queue_for_reduction(std::make_pair(nbr,dist.getValue(v) + weight.getValue(e)), std::make_pair(nbr,true));
        }

      }
    }
    g.sync_reduction();
    world.barrier();

    modified.assignCopy(modified_nxt);
    modified_nxt.attachToGraph(&g, (bool)false);
    finished = modified.aggregateValue(NOT);
  }

}

int main(int argc, char *argv[])
{
   
    boost::mpi::environment env(argc, argv);
    boost::mpi::communicator world;
    
    printf("program started\n"); 
    Graph graph(argv[1],world);
    world.barrier();

    //BC
    NodeProperty<int> dist;
    Compute_SSSP(graph, dist,graph.weights,0, world);
    for(int i=graph.start_node() ;i<=graph.end_node();i++)
    {
        printf("%d %d\n", i, dist.getValue(i));
    }
    
    world.barrier();
    return 0;
}