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
                # p "hej" + current_user.to_s
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

def login_snake(username, password)
    db = set_db()
    result = db.execute("SELECT id, password_digest, class_name FROM users WHERE username = ?", username)
    admin = false

    # p result

    if result.empty?    
        errormsg = "Invalid credentials"
    else
        password_digest = result.first["password_digest"]
        if BCrypt::Password.new(password_digest) == password
            current_user = result.first["id"]
            errormsg = nil

            if result.first['class_name'] == nil
                admin = true
            end
        else
            errormsg = "Incorrect password"
        end
    end

    return {current_user: current_user, error: errormsg, admin: admin}
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

def remove_option(option_id)
    db = set_db()

    db.execute('DELETE FROM options WHERE option_id=?', option_id)
    db.execute('DELETE FROM votes WHERE option_id=?', option_id)
end

def fetch_options(order)
    db = set_db()

    p order

    options = db.execute("SELECT option_id, name, class_name, content, no_of_votes FROM users LEFT JOIN options ON users.id = options.for_user WHERE option_id IS NOT NULL ORDER BY #{order}")
    
    return options
    
end