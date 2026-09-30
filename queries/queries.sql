-- 도서관 대여 관리 핵심 SQL 19개
-- 대상 DBMS: MySQL 8.4
-- 실행 전 schema/schema.sql과 data/seed.sql을 순서대로 실행한다.

USE library_learning;

-- Query 01
-- 목적: 제목에 '데이터'가 들어간 도서를 최신 출판일순으로 조회한다.
-- 학습 포인트: SELECT, WHERE, LIKE, ORDER BY
SELECT book_id, title, isbn, published_on
FROM books
WHERE title LIKE '%데이터%'
ORDER BY published_on DESC, book_id ASC;

-- Query 02
-- 목적: 2024년 이후 출판된 도서를 오래된 순서부터 확인한다.
-- 학습 포인트: WHERE 비교 연산자, ORDER BY
SELECT book_id, title, published_on, total_copies
FROM books
WHERE published_on >= '2024-01-01'
ORDER BY published_on ASC, title ASC;

-- Query 03
-- 목적: 2025년 하반기에 가입한 활성 회원을 가입일순으로 조회한다.
-- 학습 포인트: WHERE, BETWEEN, AND, ORDER BY
SELECT member_id, member_name, email, joined_on
FROM members
WHERE joined_on BETWEEN '2025-07-01' AND '2025-12-31'
  AND membership_status = 'ACTIVE'
ORDER BY joined_on ASC;

-- Query 04
-- 목적: 가장 최근에 시작된 대여 5건을 확인한다.
-- 학습 포인트: ORDER BY, LIMIT
-- MySQL 문법 설명: LIMIT는 정렬된 결과에서 지정한 개수만 반환한다.
SELECT loan_id, member_id, book_id, loaned_on, due_on, returned_on
FROM loans
ORDER BY loaned_on DESC, loan_id DESC
LIMIT 5;

-- Query 05
-- 목적: 대여 기록을 회원명과 도서명까지 연결해 상세 조회한다.
-- 학습 포인트: INNER JOIN, 다중 JOIN
-- loans가 기준 테이블이며, 실제로 존재하는 회원과 도서의 대여 기록만 반환한다.
SELECT
    l.loan_id,
    m.member_name,
    b.title,
    l.loaned_on,
    l.due_on,
    l.returned_on
FROM loans AS l
INNER JOIN members AS m ON m.member_id = l.member_id
INNER JOIN books AS b ON b.book_id = l.book_id
ORDER BY l.loan_id;

-- Query 06
-- 목적: 모든 도서가 어느 카테고리에 속하는지 확인한다.
-- 학습 포인트: INNER JOIN, 테이블 별칭
-- books가 기준 테이블이고 category_id FK로 반드시 존재하는 카테고리와 연결된다.
SELECT b.book_id, b.title, c.category_name, b.total_copies
FROM books AS b
INNER JOIN categories AS c ON c.category_id = b.category_id
ORDER BY c.category_name, b.title;

-- Query 07
-- 목적: 도서별 저자를 집필 순서대로 한 행에 모아 표시한다.
-- 학습 포인트: INNER JOIN, GROUP BY, 문자열 집계
-- book_authors가 도서와 저자의 N:M 관계를 연결한다.
-- MySQL 전용 문법: GROUP_CONCAT은 그룹에 속한 문자열을 하나로 합친다.
SELECT
    b.book_id,
    b.title,
    GROUP_CONCAT(a.author_name ORDER BY ba.author_order SEPARATOR ', ') AS authors
FROM books AS b
INNER JOIN book_authors AS ba ON ba.book_id = b.book_id
INNER JOIN authors AS a ON a.author_id = ba.author_id
GROUP BY b.book_id, b.title
ORDER BY b.book_id;

-- Query 08
-- 목적: 한 번도 대여하지 않은 회원을 찾는다.
-- 학습 포인트: LEFT JOIN, IS NULL
-- members를 기준으로 LEFT JOIN하므로 대여가 없는 회원도 남고, 그 경우 loans 열이 NULL이다.
-- INNER JOIN을 사용하면 대여 기록과 일치하지 않는 회원은 결과에서 사라진다.
SELECT m.member_id, m.member_name, m.email
FROM members AS m
LEFT JOIN loans AS l ON l.member_id = m.member_id
WHERE l.loan_id IS NULL
ORDER BY m.member_id;

-- Query 09
-- 목적: 카테고리별 등록 도서 수를 구해 장서 구성을 확인한다.
-- 학습 포인트: COUNT, GROUP BY, LEFT JOIN
-- GROUP BY는 하나의 카테고리를 한 그룹으로 묶으며, 도서가 0권인 카테고리도 보존한다.
SELECT
    c.category_id,
    c.category_name,
    COUNT(b.book_id) AS book_count
FROM categories AS c
LEFT JOIN books AS b ON b.category_id = c.category_id
GROUP BY c.category_id, c.category_name
ORDER BY book_count DESC, c.category_id;

-- Query 10
-- 목적: 누적 대여 횟수가 많은 인기 도서를 순위 형태로 확인한다.
-- 학습 포인트: COUNT, GROUP BY, LEFT JOIN, ORDER BY
-- books를 기준으로 하므로 아직 대여되지 않은 도서도 대여 횟수 0으로 표시된다.
SELECT
    b.book_id,
    b.title,
    COUNT(l.loan_id) AS loan_count
FROM books AS b
LEFT JOIN loans AS l ON l.book_id = b.book_id
GROUP BY b.book_id, b.title
ORDER BY loan_count DESC, b.book_id ASC;

-- Query 11
-- 목적: 회원별 총 대여 횟수와 완료된 대여의 평균 이용 일수를 구한다.
-- 학습 포인트: COUNT, AVG, GROUP BY, LEFT JOIN
-- MySQL 전용 문법: DATEDIFF는 두 날짜 사이의 일수 차이를 반환한다.
-- AVG는 returned_on이 NULL인 미반납 행을 제외하고 계산한다.
SELECT
    m.member_id,
    m.member_name,
    COUNT(l.loan_id) AS loan_count,
    ROUND(AVG(DATEDIFF(l.returned_on, l.loaned_on)), 1) AS avg_completed_loan_days
FROM members AS m
LEFT JOIN loans AS l ON l.member_id = m.member_id
GROUP BY m.member_id, m.member_name
ORDER BY loan_count DESC, m.member_id;

-- Query 12
-- 목적: 전체 회원의 평균 대여 횟수보다 많이 빌린 회원을 찾는다.
-- 학습 포인트: 서브쿼리, 파생 테이블, HAVING
-- 안쪽 파생 테이블이 회원별 대여 횟수를 먼저 만들고, 바깥 AVG가 그 평균을 계산한다.
SELECT
    m.member_id,
    m.member_name,
    COUNT(l.loan_id) AS loan_count
FROM members AS m
INNER JOIN loans AS l ON l.member_id = m.member_id
GROUP BY m.member_id, m.member_name
HAVING COUNT(l.loan_id) > (
    SELECT AVG(member_loan_count)
    FROM (
        SELECT m2.member_id, COUNT(l2.loan_id) AS member_loan_count
        FROM members AS m2
        LEFT JOIN loans AS l2 ON l2.member_id = m2.member_id
        GROUP BY m2.member_id
    ) AS member_counts
)
ORDER BY loan_count DESC, m.member_id;

-- Query 13
-- 목적: 현재 한 권 이상 대여 중인 회원을 JOIN 방식으로 찾는다.
-- 학습 포인트: INNER JOIN, DISTINCT, IS NULL
-- loans에서 미반납 행을 기준으로 회원을 연결하며, DISTINCT로 한 회원의 중복을 제거한다.
SELECT DISTINCT m.member_id, m.member_name, m.email
FROM loans AS l
INNER JOIN members AS m ON m.member_id = l.member_id
WHERE l.returned_on IS NULL
ORDER BY m.member_id;

-- Query 14
-- 목적: Query 13과 같은 요구를 EXISTS 서브쿼리 방식으로 해결한다.
-- 학습 포인트: 상관 서브쿼리, EXISTS
-- members의 각 행마다 미반납 대여가 존재하는지만 검사하므로 DISTINCT가 필요 없다.
SELECT m.member_id, m.member_name, m.email
FROM members AS m
WHERE EXISTS (
    SELECT 1
    FROM loans AS l
    WHERE l.member_id = m.member_id
      AND l.returned_on IS NULL
)
ORDER BY m.member_id;

-- Query 15
-- 목적: 월별 대여 건수 추이를 핵심 운영 지표로 확인한다.
-- 학습 포인트: COUNT, GROUP BY, 날짜 가공
-- GROUP BY는 대여일을 월 단위로 바꾼 값을 기준으로 행을 묶는다.
-- MySQL 전용 문법: DATE_FORMAT은 날짜를 지정한 문자열 형식으로 변환한다.
SELECT
    DATE_FORMAT(loaned_on, '%Y-%m') AS loan_month,
    COUNT(*) AS monthly_loan_count
FROM loans
GROUP BY DATE_FORMAT(loaned_on, '%Y-%m')
ORDER BY loan_month;

-- Query 16
-- 목적: 22번 대여를 반납 처리하고 변경 결과를 확인한다.
-- 학습 포인트: UPDATE, 트랜잭션, ROLLBACK
-- START TRANSACTION부터 ROLLBACK까지 함께 실행하면 학습 데이터는 원상 복구된다.
START TRANSACTION;

UPDATE loans
SET returned_on = '2026-09-10'
WHERE loan_id = 22
  AND returned_on IS NULL;

SELECT loan_id, member_id, book_id, loaned_on, due_on, returned_on
FROM loans
WHERE loan_id = 22;

ROLLBACK;

-- Query 17
-- 목적: 대여 이력이 없는 테스트 회원을 삭제하고 삭제 결과를 확인한다.
-- 학습 포인트: DELETE, NOT EXISTS, 트랜잭션, ROLLBACK
-- NOT EXISTS 조건이 있어 대여 이력이 생기면 삭제되지 않으며, 마지막에 원상 복구한다.
START TRANSACTION;

DELETE FROM members
WHERE member_id = 12
  AND NOT EXISTS (
      SELECT 1
      FROM loans
      WHERE loans.member_id = members.member_id
  );

SELECT member_id, member_name, email
FROM members
WHERE member_id = 12;

ROLLBACK;

-- Query 18
-- 목적: 도서별 현재 미반납 대여를 빠르게 찾기 위한 복합 인덱스를 생성한다.
-- 학습 포인트: CREATE INDEX, 복합 인덱스의 선두 컬럼
-- book_id 동등 조건 다음 returned_on NULL 조건을 함께 처리하는 조회 패턴을 고려했다.
-- 주의: 스키마를 다시 만들지 않고 이 문장만 재실행하면 같은 이름의 인덱스 오류가 발생한다.
CREATE INDEX idx_loans_book_returned
    ON loans (book_id, returned_on);

-- Query 19
-- 목적: 특정 도서의 미반납 대여 조회에서 옵티마이저의 인덱스 후보를 확인한다.
-- 학습 포인트: EXPLAIN, 인덱스 실행 계획
-- MySQL 문법 설명: EXPLAIN은 실제 결과가 아니라 접근 방식, 후보 키, 예상 행 수를 보여준다.
-- 데이터가 24행뿐이라 옵티마이저가 전체 스캔을 선택할 수도 있으며 이는 오류가 아니다.
EXPLAIN
SELECT loan_id, member_id, book_id, due_on
FROM loans
WHERE book_id = 3
  AND returned_on IS NULL;

