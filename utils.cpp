#include <iostream>
#include <stdio.h>

namespace TimeTracker{
  class Utils{
    public:

    static std::string int_to_string(int subject){
      char buffer [10];
      sprintf(buffer, "%d", subject);

      return std::string(buffer);
    }

    static std::string get_current_time(){
      char current_time [9];
      time_t rawtime = time(0);
      struct tm * timeinfo = localtime(&rawtime);

      strftime(current_time, 9, "%H:%M:%S", timeinfo);
      return std::string(current_time);
    }

    static std::string get_current_date(){
      char current_date [11];
      time_t rawtime = time(0);
      struct tm * timeinfo = localtime(&rawtime);

      strftime(current_date, 11, "%Y-%m-%d", timeinfo);
      return std::string(current_date);
    }
  };
}
