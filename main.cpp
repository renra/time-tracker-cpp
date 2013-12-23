#include <iostream>
#include "core.cpp"

enum Action {start, stop};

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
      std::cout << "Task name set to:" << task_name << std::endl;
      expect_task_name = false;
      continue;
    }

    if(buffer == "--start" || buffer == "-s"){
      action = start;
      std::cout << "Start tracking" << std::endl;
    }
    else if(buffer == "--stop" || buffer == "-S"){
      action = stop;
      std::cout << "Stop tracking" << std::endl;
    }
    else if(buffer == "--task-name" || buffer == "-t"){
      expect_task_name = true;
      std::cout << "Expecting task name" << std::endl;
    }
    else{
      std::cout << "Warning:: Ignoring unknown option:" << buffer << std::endl;
    }
  }

  if(expect_task_name && task_name == ""){
    std::cerr << "Warning: task name not supplied, -t ignored" << std::endl;
  }

  if(action != start && action != stop){
    std::cerr << "Action not set. Use --start(-s) or --stop(-S)" << std::endl;
    return 1;
  }

  TimeTracker::Core core;

  switch(action){
    case(start): core.start_tracking(task_name); break;
    case(stop): core.stop_tracking(); break;
    default: std::cerr << "Unknown action. This definitely should not have happened." << std::endl;
  }

  return 0;
}
