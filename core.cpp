#include <iostream>
#include <pqxx/pqxx>
#include "utils.cpp"

namespace TimeTracker{\
  class Core{
    pqxx::connection* p_conn;
    pqxx::work* p_trans;

    public:

    Core(){
      this->p_conn = new pqxx::connection(
        ""
      );

      this->p_trans = new pqxx::work(*this->p_conn);
    }

    ~Core(){
      this->p_trans->commit();
      this->p_conn->disconnect();

      delete this->p_trans;
      delete this->p_conn;
    }

    void stop_tracking(){
      std::string beginning = "UPDATE day_entries SET stop = '";
      std::string end = "' WHERE stop is NULL";

      this->p_trans->exec(
        beginning + TimeTracker::Utils::get_current_time() + end
      );
    }

    void start_tracking(std::string task_name = ""){
      this->stop_tracking();

      if(task_name != ""){
        int task_id = this->find_or_create_task(task_name);
        this->create_day_entry_with_task(task_id);
      }
      else{
        this->create_day_entry();
      }
    }

    private:

    void create_day_entry(){
      std::string part1 = "INSERT into day_entries(date, start) values('";
      std::string part2 = "', '";
      std::string part3 = "')";

      this->p_trans->exec(
        part1 + TimeTracker::Utils::get_current_date() + part2 + \
          TimeTracker::Utils::get_current_time() + part3
      );
    }

    void create_day_entry_with_task(int task_id){
      std::string part1 = "INSERT into day_entries(date, start, task_id) values('";
      std::string part2 = "', '";
      std::string part3 = "', ";
      std::string part4 = ")";

      this->p_trans->exec(
        part1 + TimeTracker::Utils::get_current_date() + part2 + \
          TimeTracker::Utils::get_current_time() + part3 + \
          TimeTracker::Utils::int_to_string(task_id) + part4
      );
    }

    int task_id_by_task_name(std::string task_name){
      std::string beginning = "SELECT id from tasks WHERE LOWER(name) = LOWER('";
      std::string end = "') ORDER BY id DESC";

      pqxx::result result_set = this->p_trans->exec(
        beginning + task_name + end
      );

      if(result_set.size() != 1){
        return 0;
      }

      return result_set[0][0].as<int>();
    }

    void create_task(std::string task_name){
      std::string beginning = "INSERT into tasks(name) values('";
      std::string end = "')";

      this->p_trans->exec(beginning + task_name + end);
    }

    int find_or_create_task(std::string task_name){
      int task_id = this->task_id_by_task_name(task_name);

      if(task_id == 0){
        this->create_task(task_name);
        task_id = this->task_id_by_task_name(task_name);
      }

      return task_id;
    }
  };
}
