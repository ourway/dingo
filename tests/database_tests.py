import psycopg2
from threading import Thread


def get_conn():
    return psycopg2.connect(
        "dbname='dingo' user='postgres' host='0.0.0.0' password='rrferl' ")


class Kon:
    def __init__(self):
        self.conn = get_conn()
        self.cur = self.conn.cursor()

    def __enter__(self):
        return self.cur

    def __exit__(self, type, value, traceback):
        self.cur.close()
        self.conn.close()


def create_tables():
    conn = get_conn()
    cur = conn.cursor()
    return cur.execute("""

        begin;
            create table if not exists invoice6 (id int primary key, data int);
            create table if not exists water5 (id int);
            insert into water5 (id) select 0 where not exists(select id from water5 limit 1);
        commit;

    """)
    conn.close()


def simple_select(num):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
    with x as (update water5 set id = id+1 returning *)
    insert into invoice6 select * from x returning *;
""")

    rows = cur.fetchall()
    for i in rows:
        print(i)
    conn.close()
    return rows


def race_condition1(num):
    with Kon() as cur:
        cur.execute("""
            begin;
            select * from invoice6 order by id limit 1;
    """)

        row1 = cur.fetchone()[0]
        cur.execute("""
            update invoice6 set data = %s where id = %s;
    """, (num, row1))
        cur.execute("""
            select data from invoice6 where id = %s;
    """, (row1, ))
        row2 = cur.fetchone()
        cur.execute('commit;')
        print(row2, num)
        assert row2[0] == num


if __name__ == "__main__":
    create_tables()
    threads = []
    for i in range(16):
        x = Thread(target=race_condition1, args=(i,))
        threads.append(x)

    [i.start() for i in threads]
    [i.join() for i in threads]
