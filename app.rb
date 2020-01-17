require "sinatra"
require "slim"
require "bcrypt"
require "SQLite3"

enable :sessions

db = SQLite3::Database.new('database/database.db')
db.results_as_hash = true

get('/') do
    slim(:index)
end

post('/sign_up') do
    username = params["username"]
    password = params["password"]
    confirm_password = params["c_password"]

    result = db.execute("SELECT id FROM users WHERE username=?", username)

    if result.empty?
        if password == confirm_password
            if password.length >= 8
                password_digest = BCrypt::Password.create(password)
                db.execute('INSERT INTO users(username, password_digest) VALUES (?,?)', [username, password_digest])
                session[:id] = db.execute('SELECT id FROM users WHERE username=?', username)
                redirect('users/home')
            else
                session[:error] = "Password is too short"
                redirect('/error')
            end
        end
        session[:error] = "Passwords don't match"
        redirect('/error')
    else
        session[:error] = "User already exists"
        redirect('/error')
    end
end


post("/login") do
    username = params["username"]
    password = params["password"]

    result = db.execute("SELECT id, password_digest FROM users WHERE username = ?", username)
    if result.empty?    
        session[:error] = "Invalid credentials"
        redirect('/error')
    else
        user_id = result.first["id"]
        password_digest = result.first["password_digest"]
        if BCrypt::Password.new(password_digest) == password
            session[:id] = db.execute('SELECT id FROM users WHERE username=?', username)
            redirect("/users/home")
        else
            session[:error] = "Wrong password"
            redirect('/error')
        end
    end
end

post('/users/logout') do
    session[:id] = nil
    redirect('/')
end

get('/users/home') do
    if session[:id] == nil
        session[:error] = "Not logged in"
        redirect('/error')
    else
        # id_num = session[:id][0]["id"]
        # result = db.execute('SELECT id,content FROM to_dos WHERE user_id = ?', id_num)
        result = "hello"
        slim(:"users/home", locals:{list: result})
    end
end

post('/users/set_name') do 
    new_name = params["new_name"]

    db = db.execute("UPDATE users SET name=#{new_name.to_s} WHERE id=?", session[:id])
    # ???
    redirect('/users/home')
end

get('/error') do
    slim(:error, locals:{error_message: session[:error]})
end