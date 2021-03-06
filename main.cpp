#include <iostream>
#include "core.cpp"

enum Action {start, stop, search, get_current};

int main(int argc, char* argv [])
{
  if (argc < 2){
    std::cerr << "Too few arguments" << std::endl;
    return 1;
  }

  Action action;
  std::string task_name = "";
  bool expect_task_name = false;

  std::string buffer;

  for(int i = 1; i < argc; i++){
    buffer = argv[i];

    if(expect_task_name){
      task_name = buffer;
      //std::cout << "Task name set to:" << task_name << std::endl;
      expect_task_name = false;
      continue;
    }

    if(buffer == "--start" || buffer == "-s"){
      action = start;
      //std::cout << "Start tracking" << std::endl;
    }
    else if(buffer == "--stop" || buffer == "-S"){
      action = stop;
      //std::cout << "Stop tracking" << std::endl;
    }
    else if(buffer == "--search" || buffer == "-se"){
      action = search;
      //std::cout << "Search task name" << std::endl;
    }
    else if(buffer == "--current" || buffer == "-c"){
      action = get_current;
      //std::cout << "Get current" << std::endl;
    }
    else if(buffer == "--task-name" || buffer == "-t"){
      expect_task_name = true;
      //std::cout << "Expecting task name" << std::endl;
    }
    else{
      std::cout << "Warning:: Ignoring unknown option:" << buffer << std::endl;
    }
  }

  if(expect_task_name && task_name == ""){
    std::cerr << "Warning: task name not supplied, -t ignored" << std::endl;
  }

  if(action != start && action != stop && action != search && action != get_current){
    std::cerr << "Action not set. Use --start(-s) or --stop(-S) or --search(-se)";
    std::cerr << std::endl;
    return 1;
  }

  TimeTracker::Core core;

  switch(action){
    case(start): core.start_tracking(task_name); break;
    case(stop): core.stop_tracking(); break;
    case(search): core.search_task_name(task_name); break;
    case(get_current): core.get_current(); break;
    default: std::cerr <<
      "Unknown action. This definitely should not have happened." <<
      std::endl;
  }

  return 0;
}
