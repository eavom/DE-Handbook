select * 
from employee
group by all -- to group it by all the selected fields
having count(1) > 1 -- fetching only those records having value more than 1