#include <iostream>
#include <string>
#include <pqxx/pqxx>

std::string int_to_string(int subject){
  char buffer [10];
  sprintf(buffer, "%d", subject);

  return std::string(buffer);
}

std::string get_current_time(){
  char current_time [9];
  time_t rawtime = time(0);
  struct tm * timeinfo = localtime(&rawtime);

  strftime(current_time, 9, "%H:%M:%S", timeinfo);
  return std::string(current_time);
}

std::string get_current_date(){
  char current_date [11];
  time_t rawtime = time(0);
  struct tm * timeinfo = localtime(&rawtime);

  strftime(current_date, 11, "%Y-%m-%d", timeinfo);
  return std::string(current_date);
}

void create_day_entry(pqxx::work * _p_transaction){
  std::string part1 = "INSERT into day_entries(date, start) values('";
  std::string part2 = "', '";
  std::string part3 = "')";

  _p_transaction->exec(
    part1 + get_current_date() + part2 + get_current_time() + part3
  );
}

void create_day_entry_with_task(pqxx::work * _p_transaction, int task_id){
  std::string part1 = "INSERT into day_entries(date, start, task_id) values('";
  std::string part2 = "', '";
  std::string part3 = "', ";
  std::string part4 = ")";

  _p_transaction->exec(
    part1 + get_current_date() + part2 + get_current_time() + part3 + \
      int_to_string(task_id) + part4
  );
}

int task_id_by_task_name(pqxx::work * _p_transaction, std::string task_name){
  std::string beginning = "SELECT id from tasks WHERE name = LOWER('";
  std::string end = "') ORDER BY id DESC";

  pqxx::result result_set = _p_transaction->exec(beginning + task_name + end);

  if(result_set.size() != 1){
    return 0;
  }

  return result_set[0][0].as<int>();
}

void create_task(pqxx::work * _p_transaction, std::string task_name){
  std::string beginning = "INSERT into tasks(name) values('";
  std::string end = "')";

  _p_transaction->exec(beginning + task_name + end);
}

int find_or_create_task(pqxx::work * _p_transaction, std::string task_name){
  int task_id = task_id_by_task_name(_p_transaction, task_name);

  if(task_id == 0){
    create_task(_p_transaction, task_name);
    task_id = task_id_by_task_name(_p_transaction, task_name);
  }

  return task_id;
}

void stop_tracking(pqxx::work * _p_transaction){
  std::string beginning = "UPDATE day_entries SET stop = '";
  std::string end = "' WHERE stop is NULL";

  _p_transaction->exec(beginning + get_current_time() + end);
}

void start_tracking(pqxx::work * _p_transaction, std::string task_name = ""){
  stop_tracking(_p_transaction);

  if(task_name != ""){
    int task_id = find_or_create_task(_p_transaction, task_name);
    create_day_entry_with_task(_p_transaction, task_id);
  }
  else{
    create_day_entry(_p_transaction);
  }
}

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


  pqxx::connection * p_conn = new pqxx::connection(
    "dbname=time_tracking user=*** password=***"
  );

  pqxx::work * p_transaction = new pqxx::work(*p_conn);

  pqxx::result row = p_transaction->exec("select * from tasks");

  switch(action){
    case(start): start_tracking(p_transaction, task_name); break;
    case(stop): stop_tracking(p_transaction); break;
    default: std::cerr << "Unknown action. This definitely should not have happened." << std::endl;
  }

  p_transaction->commit();
  p_conn->disconnect();

  delete(p_transaction);
  delete(p_conn);

  return 0;
}


