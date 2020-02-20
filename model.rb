# before do
def set_db()
    db = SQLite3::Database.new('database/database.db')
    db.results_as_hash = true

    return db
end

def username_from_id(user_id)
    name = db.execute('SELECT username FROM users WHERE id = (?)', user_id)

    return name
end

def user_exists(username)
    db = set_db()    
    boolean = true

    result = db.execute("SELECT id FROM users WHERE username=?", username)
    if result.empty?
        boolean = false
    end

    return boolean
end

def signup_passwords(username, password, confirm)
    db = set_db()
    boolean = false

    existor = user_exists(username)
    if existor != true
        if password == confirm
            if password.length >= 4
                password_digest = BCrypt::Password.create(password)
                db.execute('INSERT INTO users(username, password_digest) VALUES (?,?)', [username, password_digest])
                current_user = db.execute('SELECT id FROM users WHERE username=?', username).first['id']
                errorsmg = nil
            else
                errormsg = "Password too short"
            end
        else
            errormsg = "Passwords don't match"
        end
    else
        errormsg = "User already exists"
    end

    return {current_user: current_user, error: errormsg}
end


def fetch_classmates(current_user)
    db = set_db()
    classmates = db.execute(
   'SELECT id, name 
    FROM users
    WHERE class_name = 
        (SELECT class_name
        FROM users
        WHERE id = (?))
    AND id IS NOT (?)', [current_user, current_user])
    return classmates                                
end